// Profile-scoped native XDG controls. No function hooks or compositor patches.
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/managers/SessionLockManager.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/protocols/LayerShell.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/config/supplementary/executor/Executor.hpp>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <format>
#include <memory>
#include <vector>
#include <linux/input-event-codes.h>
extern "C" {
#include <lua.h>
}

namespace {
struct WindowState {
    PHLWINDOWREF window;
    bool suppressedMaximize;
    CHyprSignalListener stateChanged;
};
std::vector<std::unique_ptr<WindowState>> windows;
std::vector<CHyprSignalListener> listeners;
unsigned long minimizeRequests = 0;
unsigned long resizeRequests = 0;
PHLWINDOWREF resizingWindow;
constexpr auto MAXIMIZE = Desktop::View::SUPPRESS_MAXIMIZE;

std::string userHome() {
    const char* value = std::getenv("HOME");
    return value ? value : "";
}

bool activeProfile() {
    std::ifstream input(userHome() + "/.local/state/omarchy/current/theme.name");
    std::string theme;
    std::getline(input, theme);
    return theme == "cupertino-light" || theme == "cupertino-dark";
}

void finishEdgeResize() {
    const auto window = resizingWindow.lock();
    if (window && g_layoutManager->dragController()->target() == window->layoutTarget())
        g_layoutManager->endDragTarget();
    resizingWindow.reset();
}

void edgeButton(IPointer::SButtonEvent event, Event::SCallbackInfo& info) {
    if (event.button != BTN_LEFT) return;
    if (event.state != WL_POINTER_BUTTON_STATE_PRESSED) {
        if (!resizingWindow.expired()) {
            finishEdgeResize();
            info.cancelled = true;
        }
        return;
    }
    static auto enabled = CConfigValue<Config::INTEGER>("general:resize_on_border");
    static auto border = CConfigValue<Config::INTEGER>("general:border_size");
    static auto extend = CConfigValue<Config::INTEGER>("general:extend_border_grab_area");
    if (info.cancelled || !*enabled || !activeProfile() || g_pSessionLockManager->isSessionLocked() ||
        g_layoutManager->dragController()->target() || g_pInputManager->getModsFromAllKBs() ||
        g_pInputManager->getClickMode() != CLICKMODE_DEFAULT || g_pInputManager->isConstrained()) return;
    const auto point = g_pInputManager->getMouseCoordsInternal();
    auto hitTest = Desktop::viewState()->hitTest();
    const auto window = hitTest.windowAt(point, Desktop::View::ALLOW_FLOATING |
        Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS);
    if (!window || !window->m_isMapped || !window->m_isFloating || window->isX11OverrideRedirect() ||
        Fullscreen::controller()->isFullscreen(window) || window->hasPopupAt(point)) return;
    if (g_pSeatManager->m_seatGrab && !g_pSeatManager->m_seatGrab->accepts(window->wlSurface()->resource())) return;
    const auto monitor = State::monitorState()->query().vec(point).run();
    if (!monitor) return;
    // Respect menus, panels and other layers above a window's exposed edge.
    PHLLS layer;
    Vector2D surfacePoint;
    if (hitTest.layerPopupSurfaceAt(point, monitor, &surfacePoint, &layer) ||
        hitTest.layerSurfaceAt(point, &monitor->m_layerSurfaceLayers[ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY], &surfacePoint, &layer) ||
        hitTest.layerSurfaceAt(point, &monitor->m_layerSurfaceLayers[ZWLR_LAYER_SHELL_V1_LAYER_TOP], &surfacePoint, &layer)) return;
    // Hyprland's default border grab excludes reserved titlebar extents.
    // Use the real displayed outer box, never the animated goal reported by IPC.
    const auto outer = window->getWindowBoxUnified(Desktop::View::RESERVED_EXTENTS);
    const auto area = std::max<Config::INTEGER>(0, *border + *extend);
    if (!area || outer.containsPoint(point) || !outer.copy().expand(area).containsPoint(point)) return;
    constexpr double corner = 12.0;
    unsigned int edges = Layout::CORNER_NONE;
    if (point.x < outer.x + corner) edges |= Layout::CORNER_LEFT;
    else if (point.x >= outer.x + outer.width - corner) edges |= Layout::CORNER_RIGHT;
    if (point.y < outer.y + corner) edges |= Layout::CORNER_TOP;
    else if (point.y >= outer.y + outer.height - corner) edges |= Layout::CORNER_BOTTOM;
    if (!edges) return;
    g_layoutManager->beginDragTarget(window->layoutTarget(), MBIND_RESIZE,
        static_cast<Layout::eRectCorner>(edges), true);
    if (g_layoutManager->dragController()->target() == window->layoutTarget()) {
        resizingWindow = window;
        ++resizeRequests;
        info.cancelled = true;
    }
}

std::string shellQuote(const std::string& value) {
    std::string result = "'";
    for (char c : value) result += c == '\'' ? "'\\''" : std::string(1, c);
    return result + "'";
}

void minimizeCapability(PHLWINDOW window, bool enabled) {
    if (!window->m_xdgSurface || !window->m_xdgSurface->m_surface) return;
    struct Context { PHLWINDOW window; bool enabled; } context{window, enabled};
    wl_client_for_each_resource(window->m_xdgSurface->m_surface->client(), [](wl_resource* resource, void* data) {
        const auto context = static_cast<Context*>(data);
        if (std::strcmp(wl_resource_get_class(resource), "xdg_toplevel") != 0 || wl_resource_get_version(resource) < 5)
            return WL_ITERATOR_CONTINUE;
        if (CXDGToplevelResource::fromResource(resource) != context->window->m_xdgSurface->m_toplevel.lock())
            return WL_ITERATOR_CONTINUE;
        uint32_t values[]{XDG_TOPLEVEL_WM_CAPABILITIES_FULLSCREEN, XDG_TOPLEVEL_WM_CAPABILITIES_MAXIMIZE,
                          XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE};
        wl_array capabilities{sizeof(uint32_t) * (context->enabled ? 3U : 2U), sizeof(values), values};
        static_cast<CXdgToplevel*>(wl_resource_get_user_data(resource))->sendWmCapabilities(&capabilities);
        return WL_ITERATOR_STOP;
    }, &context);
    window->m_xdgSurface->scheduleConfigure();
}

void restore(WindowState& entry) {
    if (auto window = entry.window.lock()) {
        // Restore only the bit we own; preserve all other current policy bits.
        if (entry.suppressedMaximize) window->m_suppressedEvents |= MAXIMIZE;
        else window->m_suppressedEvents &= ~static_cast<uint64_t>(MAXIMIZE);
        if (window->m_isMapped) minimizeCapability(window, false);
    }
}

void untrack(PHLWINDOW window) {
    if (resizingWindow.lock() == window) finishEdgeResize();
    std::erase_if(windows, [&](const auto& entry) {
        if (entry->window.lock() == window) {
            restore(*entry);
            return true;
        }
        return entry->window.expired();
    });
}

void minimize(PHLWINDOWREF reference) {
    const auto window = reference.lock();
    if (!window || !window->m_isMapped || !activeProfile()) return;
    const auto request = window->m_xdgSurface ? window->m_xdgSurface->m_toplevel->m_state.requestsMinimize
                                            : window->m_xwaylandSurface->m_state.requestsMinimize;
    if (!request.value_or(false)) return;
    ++minimizeRequests;
    const auto command = shellQuote(userHome() + "/.local/share/cupertino-glass/bin/cupertino-window") +
                         std::format(" minimize 0x{:x}", reinterpret_cast<uintptr_t>(window.get()));
    Config::Supplementary::executor()->spawnRaw(command);
}

void track(PHLWINDOW window) {
    if (!window || !window->m_isMapped || !activeProfile()) return;
    const auto existing = std::find_if(windows.begin(), windows.end(),
        [&](const auto& entry) { return entry->window.lock() == window; });
    if (existing == windows.end()) {
        auto entry = std::make_unique<WindowState>();
        entry->window = window;
        entry->suppressedMaximize = (window->m_suppressedEvents & MAXIMIZE) != 0;
        const PHLWINDOWREF reference = window;
        if (window->m_xdgSurface && window->m_xdgSurface->m_toplevel)
            entry->stateChanged = window->m_xdgSurface->m_toplevel->m_events.stateChanged.listen([reference] { minimize(reference); });
        else if (window->m_xwaylandSurface)
            entry->stateChanged = window->m_xwaylandSurface->m_events.stateChanged.listen([reference] { minimize(reference); });
        windows.emplace_back(std::move(entry));
        minimizeCapability(window, true);
    }
    window->m_suppressedEvents &= ~static_cast<uint64_t>(MAXIMIZE);
}

void syncProfile() {
    if (!activeProfile()) {
        finishEdgeResize();
        for (const auto& entry : windows) restore(*entry);
        windows.clear();
        return;
    }
    for (const auto& window : Desktop::windowState()->windows()) track(window);
}

int status(lua_State* state) {
    lua_newtable(state);
    lua_pushinteger(state, windows.size()); lua_setfield(state, -2, "tracked");
    lua_pushinteger(state, minimizeRequests); lua_setfield(state, -2, "minimize_requests");
    lua_pushinteger(state, resizeRequests); lua_setfield(state, -2, "resize_requests");
    lua_pushboolean(state, !resizingWindow.expired()); lua_setfield(state, -2, "resizing");
    lua_pushboolean(state, activeProfile()); lua_setfield(state, -2, "active");
    lua_newtable(state);
    for (const auto& entry : windows) {
        const auto window = entry->window.lock();
        if (!window) continue;
        const auto address = std::format("0x{:x}", reinterpret_cast<uintptr_t>(window.get()));
        lua_pushinteger(state, window->m_suppressedEvents); lua_setfield(state, -2, address.c_str());
    }
    lua_setfield(state, -2, "suppressed_events");
    lua_newtable(state);
    for (const auto& entry : windows) {
        const auto window = entry->window.lock();
        if (!window) continue;
        const auto address = std::format("0x{:x}", reinterpret_cast<uintptr_t>(window.get()));
        lua_newtable(state);
        const auto pushBox = [&](const char* name, const CBox& box) {
            lua_newtable(state);
            lua_pushnumber(state, box.x); lua_setfield(state, -2, "x");
            lua_pushnumber(state, box.y); lua_setfield(state, -2, "y");
            lua_pushnumber(state, box.width); lua_setfield(state, -2, "width");
            lua_pushnumber(state, box.height); lua_setfield(state, -2, "height");
            lua_setfield(state, -2, name);
        };
        pushBox("current", window->geometricBox(Desktop::View::IGeometric::GEOMETRIC_CURRENT));
        pushBox("goal", window->geometricBox(Desktop::View::IGeometric::GEOMETRIC_GOAL));
        pushBox("input", window->getWindowBoxUnified(Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS));
        lua_setfield(state, -2, address.c_str());
    }
    lua_setfield(state, -2, "window_geometry");
    return 1;
}
}

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string(__hyprland_api_get_hash()) != std::string(__hyprland_api_get_client_hash()))
        throw std::runtime_error("Cupertino controls: Hyprland/header ABI mismatch; plugin not loaded");
    HyprlandAPI::addLuaFunction(handle, "cupertino_bridge", "status", status);
    listeners.push_back(Event::bus()->m_events.input.mouse.button.listen(edgeButton));
    listeners.push_back(Event::bus()->m_events.window.openEarly.listen([](PHLWINDOW window) { track(window); }));
    listeners.push_back(Event::bus()->m_events.window.openLate.listen([](PHLWINDOW window) { track(window); }));
    listeners.push_back(Event::bus()->m_events.window.updateRules.listen([](PHLWINDOW window) { track(window); }));
    listeners.push_back(Event::bus()->m_events.window.close.listen([](PHLWINDOW window) { untrack(window); }));
    listeners.push_back(Event::bus()->m_events.config.reloaded.listen([] { syncProfile(); }));
    syncProfile();
    return {"cupertino-bridge", "Native maximize and minimize requests for Cupertino profiles", "Cupertino Glass", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    finishEdgeResize();
    listeners.clear();
    for (const auto& entry : windows) restore(*entry);
    windows.clear();
}
