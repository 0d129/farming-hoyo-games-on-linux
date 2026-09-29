"""Linux/Proton bootstrap for ZenlessZoneZero-OneDragon (headless).

Run by zzz-od.sh with the OneDragon embedded Windows Python under Proton.
Loads OneDragon's .venv site-packages directly, so the folder can live anywhere
(the venv's recorded home path from Windows is ignored).

Usage (via zzz-od.sh):  run [launcher args...]   -> one-dragon run (e.g. -i 1 -c)
                        enter                    -> get from the title screen / login into the world
                        app <app_id>             -> run one application, e.g. app charge_plan
                        test                     -> capture + OCR self-test, saves a screenshot
"""
import os
import site
import sys

OD = os.environ['ZZZ_OD_WINDIR']
site.addsitedir(OD + r'\.venv\Lib\site-packages')
sys.path.insert(0, OD + r'\src')
os.chdir(OD)

# Force a Wine-friendly screenshot method without touching env.yml (shared with Windows).
from one_dragon.envs import env_config as _ec
_method = os.environ.get('ZZZ_OD_SCREENSHOT', 'bitblt')
_ec.EnvConfig.screenshot_method = property(lambda self: _method, lambda self, v: None)

# Send mouse clicks through the X11 side (xinput_server.py): in the open world the game ignores
# clicks injected from inside Wine. Falls back to the normal click if the helper is not running.
_xport = os.environ.get('ZZZ_OD_XINPUT_PORT')
_xalt = os.environ.get('ZZZ_OD_XINPUT_ALT', '1')  # hold ALT while clicking (needed in the open world)
if _xport:
    import socket
    from one_dragon.base.controller import pc_controller_base as _pcb
    _orig_win_click = _pcb.win_click
    _xsock = None

    def _x_win_click(pos=None, press_time: float = 0.1, primary: bool = True):
        global _xsock
        if pos is None:
            pos = _pcb.get_current_mouse_pos()
        try:
            if _xsock is None:
                _xsock = socket.create_connection(('127.0.0.1', int(_xport)), timeout=10)
            _xsock.sendall(f'click {pos.x} {pos.y} {press_time} {1 if primary else 0} {_xalt}\n'.encode())
            if _xsock.recv(16).strip() == b'ok':
                return
        except OSError:
            _xsock = None
        _orig_win_click(pos, press_time, primary)

    _pcb.win_click = _x_win_click


def patch_back_to_world() -> None:
    # "Back to world" clicks the top-left Back arrow until it sees the world. A click that lands
    # just after the screen changed hits the world's menu button (same spot) and opens the menu,
    # and the next step then clicks into the menu by mistake. So when it reaches the world right
    # after pressing something, wait and check once more before reporting success.
    from zzz_od.operation.back_to_normal_world import BackToNormalWorld
    node = BackToNormalWorld.check_screen_and_run.operation_node_annotation
    orig = node.op_method

    def checked(self):
        result = orig(self)
        if not result.is_success:
            self._linux_pressed = True
        elif getattr(self, '_linux_pressed', False) and not getattr(self, '_linux_rechecked', False):
            self._linux_rechecked = True
            return self.round_retry('确认仍在大世界', wait=1.5)
        return result

    node.op_method = checked


def selftest() -> int:
    import time
    import cv2
    from zzz_od.context.zzz_context import ZContext
    ctx = ZContext()
    ctx.init()
    ctrl = ctx.controller
    ctrl.init_game_win()
    if not ctrl.is_game_window_ready:
        print('FAIL: game window not found - start ZZZ from Steam first', flush=True)
        return 1
    ctrl.game_win.active()
    time.sleep(1)
    if not ctrl.game_win.is_win_active:
        # BitBlt copies whatever is on screen over the game's area, so a covered game gives a false result
        print('FAIL: game window is not in the foreground (something is covering it)', flush=True)
        return 1
    img = ctrl.get_screenshot()
    if img is None:
        print('FAIL: screenshot returned None', flush=True)
        return 1
    out = os.path.join(OD, '.debug', 'linux_selftest.png')
    cv2.imwrite(out, cv2.cvtColor(img, cv2.COLOR_RGB2BGR))
    print(f'screenshot {img.shape} mean={img.mean():.1f} std={img.std():.1f} saved {out}', flush=True)
    texts = list(ctx.ocr.run_ocr(img).keys())
    print(f'OCR found {len(texts)} text items: {texts[:15]}', flush=True)
    ok = img.std() > 5 and len(texts) > 0
    print('PASS' if ok else 'FAIL: image looks blank', flush=True)
    return 0 if ok else 1


def enter() -> int:
    # One-dragon only runs its own enter-game step when it launched the game itself. Under Proton the
    # game is started by Steam, so run EnterGame (title screen -> login -> world) here instead.
    # OpenGame is not used: it would start a second copy of the exe outside Steam.
    from zzz_od.context.zzz_context import ZContext
    from zzz_od.operation.enter_game.enter_game import EnterGame
    ctx = ZContext()
    ctx.init()
    ctx.controller.init_game_win()
    if not ctx.controller.is_game_window_ready:
        print('FAIL: game window not found - start ZZZ from Steam first', flush=True)
        return 1
    ctx.run_context.start_running()
    op = EnterGame(ctx)
    # EnterGame only looks for the world after clicking "enter" on the title screen, so it fails
    # when the game is already in the world. Check that first with its own world check.
    screen = ctx.controller.get_screenshot()
    if screen is not None and op.is_in_big_world(screen) is not None:
        ctx.run_context.stop_running()
        print('enter game: success=True status=already in world', flush=True)
        return 0
    result = op.execute()
    ctx.run_context.stop_running()
    print(f'enter game: success={result.success} status={result.status}', flush=True)
    return 0 if result.success else 1


def run_app(app_id: str) -> int:
    # Run a single application (e.g. charge_plan) the way the launcher runs one-dragon.
    from one_dragon.base.operation.application import application_const
    from zzz_od.context.zzz_context import ZContext
    ctx = ZContext()
    ctx.init()
    try:
        result = ctx.run_context.run_application(app_id=app_id, instance_idx=ctx.current_instance_idx,
                                                 group_id=application_const.DEFAULT_GROUP_ID)
        print(f'app {app_id}: {result}', flush=True)
    finally:
        ctx.after_app_shutdown()
    return 0


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'run'
    patch_back_to_world()
    if mode in ('test', 'enter', 'app'):
        code = selftest() if mode == 'test' else enter() if mode == 'enter' else run_app(sys.argv[2])
        sys.stdout.flush()
        os._exit(code)
    from zzz_od.application.zzz_application_launcher import main
    main(sys.argv[2:])
