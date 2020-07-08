import sdl2/sdl, sdl2/sdl_gfx_primitives as gfx, math

discard sdl.init(INIT_EVERYTHING)

const
  FRAMES_PER_SECOND = 60
  MS_PER_FRAME = uint32(1000 / FRAMES_PER_SECOND)

type Point = array[0..1, float]
type Sphere = array[0..9, array[0..9, Point]]

var
  window: sdl.Window = sdl.createWindow("Amiga Boing Ball", 100, 100, 640, 512,
                                        WINDOW_OPENGL)
                                        #WINDOW_FULLSCREEN)
  render: sdl.Renderer = sdl.createRenderer(window, -1,
                                            Renderer_Accelerated or
                                            Renderer_PresentVsync or
                                            Renderer_TargetTexture)
  evt: sdl.Event

var
  scale = 120.0
  phase = 0.0
  dp = 2.5
  x = 320.0
  dx = 2.1
  right = true
  y_ang = 0.0
  y = 0.0

proc do_physics() =
  var phase_shift = dp
  if right: phase_shift = 45.0 - dp
  phase = (phase + phase_shift) mod 45.0
  if right: x += dx else: x -= dx
  if x >= 505: right = false elif x <= 135: right = true
  y_ang = (y_ang + 1.5) mod 360.0
  y = 350.0 - 200.0 * abs(cos(y_ang * math.PI / 180.0))

func get_lat(phase: float, i: int): float =
  if i == 0:
    return -90.0
  elif i == 9:
    return 90.0
  else:
    return -90.0 + phase + (float(i) - 1.0) * 22.5

proc calc_points(phase: float): Sphere =
  let zp: Point = [0.0, 0.0]
  var points: Sphere = [[zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp],
                        [zp,zp,zp,zp,zp,zp,zp,zp,zp,zp]]
  var sin_lat: array[0..9, float]
  for i in 0..9:
    let lat = get_lat(phase, i)
    sin_lat[i] = math.sin(lat * math.PI / 180.0)

  for j in 0..8:
    let lon = -90.0 + float(j) * 22.5
    let y = math.sin(lon * math.PI / 180.0)
    let l = math.cos(lon * math.PI / 180.0)
    for i in 0..9:
      let x = sin_lat[i] * l
      points[i][j] = [x, y]

  return points

func tilt_sphere(points: var Sphere, ang: float) =
  let st = sin(ang * math.PI / 180.0)
  let ct = cos(ang * math.PI / 180.0)
  for i in 0..9:
    for j in 0..9:
      let pt = points[i][j]
      let x = pt[0] * ct - pt[1] * st
      let y = pt[0] * st + pt[1] * ct
      points[i][j] = [x, y]

func scale_and_translate(points: var Sphere, s: float, tx: float, ty: float) =
  for i in 0..9:
    for j in 0..9:
      let pt = points[i][j]
      let x = pt[0] * s + tx
      let y = pt[1] * s + ty
      points[i][j] = [x, y]

func transform(points: var Sphere, s: float, tx: float, ty: float) =
  tilt_sphere(points, 17.0)
  scale_and_translate(points, s, tx, ty)

proc fill_tiles(points: var Sphere, alter: var bool) =
  const polyN = 4
  for j in 0..7:
    for i in 0..8:
      let p1 = points[i][j]
      let p2 = points[i+1][j]
      let p3 = points[i+1][j+1]
      let p4 = points[i][j+1]
      var polyX, polyY: array[polyN, int16]
      polyX[0] = int16(p1[0])
      polyY[0] = int16(p1[1])
      polyX[1] = int16(p2[0])
      polyY[1] = int16(p2[1])
      polyX[2] = int16(p3[0])
      polyY[2] = int16(p3[1])
      polyX[3] = int16(p4[0])
      polyY[3] = int16(p4[1])

      var # white
        r: uint8 = 255
        g: uint8 = 255
        b: uint8 = 255
      if alter: # red
        r = 255
        g = 0
        b = 0
      discard gfx.filledPolygonRGBA(render,
        vx = addr(polyX[0]), vy = addr(polyY[0]), n = polyN, r, g, b, 255)

      alter = not alter

proc draw_shadow(points: Sphere) =
  var polyX, polyY: array[0..16, int16]

  for i in 0..8:
    let p = points[0][i]
    polyX[i] = int16(p[0]) + 50
    polyY[i] = int16(p[1])
  for i in 0..8:
    let p = points[9][8 - i]
    polyX[7 + i] = int16(p[0]) + 50
    polyY[7 + i] = int16(p[1])

  #echo polyX
  #echo polyY

  var #gray
    r: uint8 = 102
    g: uint8 = 102
    b: uint8 = 102
  discard gfx.filledPolygonRGBA(render,
    vx = addr(polyX[0]), vy = addr(polyY[0]), n = 15, r, g, b, 255)

proc draw_wireframe() =
  discard render.setRenderDrawColor(183'u8, 45'u8, 168'u8, 255'u8) # purple
  discard render.renderSetScale(1, 1)

  for i in 0..12:
    let y = cint(i * 36)
    discard render.renderDrawLine(50, y, 590, y)

  for i in 0..15:
    let x = cint(50 + i * 36)
    discard render.renderDrawLine(x, 0, x, 432)

  for i in 0..15:
    discard render.renderDrawLine(cint(50 + i * 36), 432, cint(float(i) * 42.666), 480)

  let ys = [442, 454, 468]
  for i in 0..2:
    let y = ys[i]
    let x1 = 50.0 - 50.0 * (float(y) - 432.0) / (480.0 - 432.0)
    discard render.renderDrawLine(cint(x1), cint(y), cint(640 - x1), cint(y))

proc clear_background() =
  discard render.setRenderDrawColor(170'u8, 170'u8, 170'u8, 255'u8) # light gray
  discard render.renderClear

proc sync_framerate(start_ticks: uint32) =
  let frame_ms = sdl.get_ticks() - start_ticks
  if frame_ms < MS_PER_FRAME: sdl.delay(MS_PER_FRAME - frame_ms)

proc listen_for_events() =
  while sdl.pollEvent(addr(evt)) != 0:
    if evt.kind == sdl.Quit or evt.key.keysym.sym == sdl.K_Escape:
      discard render
      discard window
      quit 0

proc run_loop() =
  clear_background()
  do_physics()
  var points = calc_points(phase mod 22.5)
  transform(points, scale, x, y)
  draw_shadow(points)
  draw_wireframe()
  var pbool: bool = phase >= 22.5
  fill_tiles(points, pbool)


# main loop
while true:
  listen_for_events()
  let start_ticks = sdl.get_ticks()
  run_loop()
  render.renderPresent()
  sync_framerate(start_ticks)
