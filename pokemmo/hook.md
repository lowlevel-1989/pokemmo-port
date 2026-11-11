## El flujo completo, con westonpack y el hook
```
PokeMMO.sh
  └─ westonwrap.sh
       ├─ seatd + weston (headless, noop) + Xwayland      ← "escritorio" falso para X11
       └─ PokeMMO  (LD_PRELOAD = libcrusty.so : libshaderfix.so)
            │
            │  SDL3 abre una ventana X11 en Xwayland y pide OpenGL (GLX)
            ▼
         [HOOK GLX]  ← captura y sustituye default/depth
            ▼
         libGL.so.1 de gl4es   → traduce OpenGL de escritorio a GLES 2
            ▼
         [HOOK EGL]  ← dump y errores de compilación
            ▼
         libcrusty.so          → lleva el resultado de GLX/X11 al EGL real del dispositivo
            ▼
         libmali (EGL/GLES)    → GPU → pantalla
```

## Sin westonpack (Panfrost/Mesa)
```
PokeMMO ──► [HOOK GLX] ──► libGL de Mesa ──► GPU
```
