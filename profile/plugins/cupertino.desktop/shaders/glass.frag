#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 surfaceSize;
    float cornerRadius;
    float materialOpacity;
    float darkMode;
    float emphasis;
    float shadowStrength;
    float shadowPadding;
    vec2 backdropSize;
    vec2 backdropImageSize;
    vec2 backdropOrigin;
    float refraction;
    float backdropEnabled;
    float lightFocus;
    float lightActivity;
    float edgeStrength;
    float opticalLift;
    float lensWidth;
    float lensOpacity;
    float panelOptics;
    vec4 materialColor;
    float backdropSaturation;
    float backdropBrightness;
} ub;
layout(binding=1) uniform sampler2D backdrop;
float roundedBox(vec2 p,vec2 halfSize,float r) {
    vec2 q=abs(p)-halfSize+r;
    return length(max(q,0.0))+min(max(q.x,q.y),0.0)-r;
}
float sdf(vec2 p) { return roundedBox(p-ub.surfaceSize*0.5,ub.surfaceSize*0.5,ub.cornerRadius); }
vec4 over(vec4 fg,vec4 bg) { return fg+bg*(1.0-fg.a); }
vec3 wallpaper(vec2 point) {
    // Match Omarchy's centered PreserveAspectCrop on each monitor.
    float scale=max(ub.backdropSize.x/ub.backdropImageSize.x,ub.backdropSize.y/ub.backdropImageSize.y);
    vec2 covered=ub.backdropImageSize*scale;
    vec2 uv=(point+(covered-ub.backdropSize)*0.5)/covered;
    vec2 blur=vec2(1.8)/covered;
    vec3 c=texture(backdrop,uv).rgb*0.4;
    c+=texture(backdrop,uv+vec2(blur.x,blur.y)).rgb*0.15;
    c+=texture(backdrop,uv+vec2(-blur.x,blur.y)).rgb*0.15;
    c+=texture(backdrop,uv+vec2(blur.x,-blur.y)).rgb*0.15;
    c+=texture(backdrop,uv-vec2(blur.x,blur.y)).rgb*0.15;
    float luminance=dot(c,vec3(0.2126,0.7152,0.0722));
    return clamp(mix(vec3(luminance),c,ub.backdropSaturation)+ub.backdropBrightness,0.0,1.0);
}
void main() {
    vec2 p=qt_TexCoord0*(ub.surfaceSize+2.0*ub.shadowPadding)-ub.shadowPadding;
    vec2 centre=ub.surfaceSize*0.5;
    float d=sdf(p);
    float aa=max(fwidth(d),0.6);
    float cover=1.0-smoothstep(-aa*0.5,aa*0.5,d);
    float depth=max(0.0,-d);
    vec2 n=normalize(vec2(sdf(p+vec2(0.3,0))-sdf(p-vec2(0.3,0)),sdf(p+vec2(0,0.3))-sdf(p-vec2(0,0.3)))+vec2(0.00001));
    float shadowD=max(0.0,roundedBox(p-centre-vec2(0,1.8),centre,ub.cornerRadius));
    float shadow=(0.65*exp(-shadowD*shadowD/26.0)+0.35*exp(-shadowD*shadowD/3.0))*ub.shadowStrength;
    shadow*=(1.0-cover)*(1.0-smoothstep(max(0.0,ub.shadowPadding-3.0),ub.shadowPadding,d));
    vec4 result=vec4(0,0,0,shadow);
    vec3 neutral=ub.materialColor.rgb;
    float alpha=clamp(ub.materialOpacity+ub.emphasis*0.035,0.0,1.0)*cover;
    result=over(vec4(neutral*alpha,alpha),result);
    float lift=ub.opticalLift*(0.45+0.55*(1.0-clamp(p.y/ub.surfaceSize.y,0.0,1.0)))*cover;
    result=over(vec4(vec3(lift),lift),result);
    float lens=exp(-depth*depth/max(1.0,ub.lensWidth*ub.lensWidth));
    if(ub.backdropEnabled>0.5 && ub.refraction>0.0 && cover>0.0) {
        vec2 displaced=ub.backdropOrigin+p-n*(ub.refraction*lens);
        vec3 refracted=wallpaper(displaced);
        refracted=mix(refracted,neutral,ub.materialOpacity*0.45);
        float lensAlpha=ub.lensOpacity*lens*cover;
        result=over(vec4(refracted*lensAlpha,lensAlpha),result);
    }
    // The contour changes with its normal: key light above-left, weaker return below-right.
    // Two narrow bands suggest thickness without a uniform white plastic outline.
    float key=pow(max(dot(n,normalize(vec2(-0.42,-0.91))),0.0),2.0);
    float returning=pow(max(dot(n,normalize(vec2(0.52,0.85))),0.0),3.0);
    // A second, wider reflection separates the lens wall from the flat interior.
    // It is directional and confined to the perimeter, never a grey full-card fill.
    float bevel=exp(-pow((depth-3.5)/3.0,2.0))*cover*ub.panelOptics;
    float reflected=(0.038*key+0.018*returning)*bevel;
    result=over(vec4(vec3(reflected),reflected),result);
    float rim=exp(-pow((depth-0.55)/0.48,2.0))*cover;
    float inner=exp(-pow((depth-2.0)/1.0,2.0))*cover;
    float focus=exp(-pow((p.x/ub.surfaceSize.x-ub.lightFocus)/0.22,2.0))*ub.lightActivity;
    float glint=(0.018+0.20*key+0.115*returning+0.05*focus)*rim;
    glint+=(0.025*key+0.026*returning+0.009*focus)*inner;
    glint*=ub.edgeStrength;
    result=over(vec4(vec3(glint),glint),result);
    float recess=exp(-pow((depth-1.3)/0.65,2.0))*(1.0-key)*0.035*cover;
    result=over(vec4(0,0,0,recess),result);
    fragColor=result*ub.qt_Opacity;
}
