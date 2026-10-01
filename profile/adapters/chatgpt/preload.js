// Executed in Electron's isolated preload world, alongside the original preload.
(() => {
  const { ipcRenderer } = require('electron');
  const channel = 'cupertino:local-window-frame:v1';
  let state = null, group = null, observer = null, pending = false;
  const doubleClickHeaders = new WeakSet();
  const css = `
    :root[data-cupertino-app="mac"][data-cupertino-color="dark"] {
      --app-color-background-surface:#24273a!important;
      --app-color-background-surface-under:#24273a!important;
      --app-color-background-editor-opaque:#24273a!important;
      --app-color-background-recovery:#24273a!important;
      --app-color-background-shell:#24273a!important;
      --app-color-background-elevated-primary:#363a4f!important;
      --app-color-background-elevated-primary-opaque:#363a4f!important;
      --app-color-background-card:#363a4f!important;
      --app-color-text-foreground:#cad3f5!important;
      --app-color-text-foreground-secondary:#b8c0e0!important;
      --app-color-text-foreground-tertiary:#a5adcb!important;
      --app-color-text-button-primary:#24273a!important;
      --color-text-inverse:#24273a!important;
      --color-text-primary-solid:#24273a!important;
      --color-codex-description:#a5adcb!important;
      --app-color-border:#494d64!important;
      --color-border:#494d64!important;
      --color-text:#cad3f5!important;
      --color-text-emphasis:#cad3f5!important;
      --codex-titlebar-tint:#24273a!important;
    }
    :root[data-cupertino-app="mac"] [data-app-shell-frame] {
      --spacing-token-safe-header-left:82px!important;
      --spacing-token-safe-header-right:8px!important;
    }
    [data-cupertino-app-header="mac"] { padding-left:82px!important; }
    [data-cupertino-app-header="standard"] { padding-right:126px!important; }
    #cupertino-app-controls { position:fixed;left:10px;top:0;width:66px;height:32px;display:flex;
      align-items:center;gap:0;-webkit-app-region:no-drag;user-select:none;pointer-events:auto;z-index:10000; }
    #cupertino-app-controls button { all:unset;box-sizing:border-box;width:22px;height:26px;
      display:grid;place-items:center;-webkit-app-region:no-drag;cursor:default; }
    #cupertino-app-controls button svg { display:block;width:12px;height:12px;overflow:visible;pointer-events:none; }
    #cupertino-app-controls .control-glyph { opacity:0;stroke:var(--control-glyph);stroke-width:.85;
      stroke-linecap:round;stroke-linejoin:round;fill:none; }
    #cupertino-app-controls button[data-action="maximize"] .control-glyph { fill:var(--control-glyph);stroke:none; }
    #cupertino-app-controls:hover .control-glyph,
    #cupertino-app-controls button:focus-visible .control-glyph {opacity:1;}
    #cupertino-app-controls button:focus-visible {outline:2px solid #8aadf4;outline-offset:-1px;border-radius:5px;}
    #cupertino-app-controls button:active svg {filter:brightness(.86);}
    #cupertino-app-controls[data-active="false"] {left:auto;right:0;width:120px;flex-direction:row-reverse;}
    #cupertino-app-controls[data-active="false"] button {width:40px;height:100%;color:inherit;}
    #cupertino-app-controls[data-active="false"] circle {display:none;}
    #cupertino-app-controls[data-active="false"] .control-glyph {opacity:1;stroke:currentColor;}
    #cupertino-app-controls[data-active="false"] button:hover {background:#80808030;}
    #cupertino-app-controls[data-active="false"] button[data-action="close"]:hover {background:#e81123;color:white;}
  `;  function mount() {
    pending = false;
    if (!state?.adapted || !document.body) return;
    const candidates = [...document.querySelectorAll('._ApplicationMenuTopBar_bo1ta_2,[data-window-titlebar],header.draggable,.fixed.inset-x-0.top-0.draggable,.absolute.inset-x-0.top-0.draggable')];
    const header = candidates.find(el => {
      const rect=el.getBoundingClientRect();
      return rect.height>0 && rect.top<=2 && !el.classList.contains('pointer-events-none');
    });
    if (header && !doubleClickHeaders.has(header)) {
      doubleClickHeaders.add(header);
      header.addEventListener('dblclick', event => {
        if (!state?.active || !event.isTrusted || event.button !== 0 ||
            event.target.closest('button,a,input,textarea,select,[contenteditable="true"],[role="button"]')) return;
        event.preventDefault();event.stopImmediatePropagation();
        ipcRenderer.invoke(channel,'maximize').catch(()=>{});
      }, true);
    }
    if (!document.getElementById('cupertino-app-control-style')) {
      const style = document.createElement('style');style.id='cupertino-app-control-style';
      style.textContent=state.css || css;document.head.append(style);
    }
    const currentStyle = document.getElementById('cupertino-app-control-style');
    if (currentStyle.textContent !== (state.css || css)) currentStyle.textContent = state.css || css;
    if (!group) {
      group=document.createElement('div');group.id='cupertino-app-controls';
      group.setAttribute('role','group');group.setAttribute('aria-label','Controles de ventana');
      for (const [action,label,color,top,bottom,border,glyph,shape] of [
        ['close','Cerrar','#ff5f57','#ff6b63','#f55b53','#c7443c','#761a16','M1.5 1.5L6.5 6.5M6.5 1.5L1.5 6.5'],
        ['minimize','Minimizar','#febc2e','#ffc540','#f3b329','#b98118','#775000','M1.5 4H6.5'],
        ['maximize','Maximizar o restaurar','#28c840','#3bcf50','#24be3b','#15942a','#075e15','M1.6 1.6h3.2L1.6 4.8zM6.4 6.4H3.2l3.2-3.2z']
      ]) {
        const button=document.createElement('button');button.type='button';button.dataset.action=action;
        button.setAttribute('aria-label',label);button.title=label;button.style.setProperty('--control-color',color);
        for(const [name,value] of Object.entries({top,bottom,border,glyph}))button.style.setProperty('--control-'+name,value);
        const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 12 12');
        const disc=document.createElementNS(svg.namespaceURI,'circle');disc.setAttribute('cx','6');disc.setAttribute('cy','6');disc.setAttribute('r','5.75');
        disc.setAttribute('fill',color);disc.setAttribute('stroke',border);disc.setAttribute('stroke-width','.5');svg.append(disc);
        const glyphPath=document.createElementNS(svg.namespaceURI,'path');glyphPath.classList.add('control-glyph');
        glyphPath.setAttribute('d',shape);glyphPath.setAttribute('transform','translate(2 2)');svg.append(glyphPath);button.append(svg);
        button.addEventListener('click',event=>{if(event.isTrusted)ipcRenderer.invoke(channel,action).catch(()=>{});});
        group.append(button);
      }
      group.addEventListener('dblclick',event=>event.stopPropagation());
    }
    const mode=state.active?'mac':'standard';
    document.documentElement.dataset.cupertinoApp=mode;
    document.documentElement.dataset.cupertinoColor=state.theme==='cupertino-dark'?'dark':'light';
    if (header && header.dataset.cupertinoAppHeader !== mode) header.dataset.cupertinoAppHeader=mode;
    group.dataset.active=String(state.active);group.dataset.focused=String(state.focused);
    // React replaces the top bar during navigation. Keep the controls outside
    // its owned subtree while reserving their space in the existing header.
    if (group.parentElement !== document.body) document.body.append(group);
    group.style.display=state.fullscreen?'none':'flex';
  }
  function schedule() { if(!pending){pending=true;requestAnimationFrame(mount);} }
  // Apply profile changes even while a minimized renderer has paused animation frames.
  function update(next) { if(next){state=next;mount();} }
  ipcRenderer.on(channel,(_event,next)=>update(next));
  function start() {
    observer=new MutationObserver(changes=>{
      if(changes.some(change=>change.type==='childList' && change.target!==group))schedule();
    });
    observer.observe(document.body,{childList:true,subtree:true});
    ipcRenderer.invoke(channel,'state').then(update).catch(()=>{});
    schedule();
  }
  document.readyState==='loading'?document.addEventListener('DOMContentLoaded',start,{once:true}):start();
})();
