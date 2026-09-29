"""Linux/Proton bootstrap for ZenlessZoneZero-OneDragon (headless).

Run by zzz-od.sh with the OneDragon embedded Windows Python under Proton.
Loads OneDragon's .venv site-packages directly, so the folder can live anywhere
(the venv's recorded home path from Windows is ignored).

Usage (via zzz-od.sh):  run [launcher args...]   -> one-dragon run (e.g. -i 1 -c)
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


if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'run'
    if mode == 'test':
        code = selftest()
        sys.stdout.flush()
        os._exit(code)
    from zzz_od.application.zzz_application_launcher import main
    main(sys.argv[2:])
