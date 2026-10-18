#!/usr/bin/env python3
"""Edit MAA's (WPF GUI) config/gui.new.json for the Arknights PC client under Wine.
MAA must be closed: it rewrites the file on exit.

  maa_config.py <gui.new.json> setup <game exe> [discord webhook]
  maa_config.py <gui.new.json> autorun on|off
  maa_config.py <gui.new.json> meow <maameow_config.json>
  maa_config.py <gui.new.json> show

setup    PC connection (Win32: ScreenDC screenshots, Seize mouse input), MAA starts the game windowed
         itself, MAA's own schedule off (farm-chain runs it), no system notifications (under Wine
         they steal the mouse focus until closed), Discord webhook if given.
autorun  on: MAA runs its task queue right after it starts and exits when done (for farm-chain).
         off: put back what was there before `on`.
meow     copy the task settings of a MAA-Meow (Android) export onto the current MAA profile.
"""
import json
import os
import shutil
import sys
import time


def load(path):
    return json.load(open(path, encoding='utf-8'))


def save(path, d):
    tmp = path + '.tmp'
    json.dump(d, open(tmp, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def profile(d):
    return d['Configurations'][d.get('Current') or 'Default']


def winpath(p):
    return 'Z:' + os.path.abspath(p).replace('/', '\\')


def setup(d, game_exe, webhook=''):
    g = profile(d)['Gui']
    cs = g['ConnectSettings']
    cs['Config'] = 'PC'
    # Unity ignores the posted window messages of the PostMessage* methods under Wine, so only
    # Seize (real SendInput, it moves the mouse) gets clicks through. The game draws with DXVK, so
    # PrintWindow only returns black; ScreenDC copies that part of the screen, which is right as
    # long as the game is a window (fullscreen also catches the taskbar) and nothing covers it.
    cs['Extras']['Win32Extra'].update(ScreencapMethod='ScreenDC', MouseMethod='Seize', MuteWhileRunning=True)
    g['StartUpSettings'].update(StartPcClient=True, RestartPcClientWhenConnectFailed=True,
                                PcClientPath=winpath(game_exe),
                                PcClientAddCommand='-launcher_lang=zh-cn -launcher_sub_channel=1'
                                ' -screen-fullscreen 0 -screen-width 1280 -screen-height 720',
                                PcClientWaitSeconds=60)
    d['Gui']['UseNotify'] = False
    for t in d['Timers']['List']:
        t['IsEnabled'] = False
    if webhook:
        en = g['ExternalNotification']
        # MAA keeps these DPAPI-encrypted; a plain value still works (MAA warns once, then
        # encrypts it the next time the setting is saved from its settings page).
        en['Configs'] = [c for c in en['Configs'] if c.get('$type') != 'CustomWebhook'
                         and not (c.get('$type') == 'Discord' and not c.get('BotToken'))]
        en['Configs'].append({'$type': 'CustomWebhook', 'Url': webhook, 'Headers': '',
                              'Body': '{"content": "{content}"}'})   # MAA's "Discord Webhook" template
        en['Delivery'].update(Enable=True, SendWhenComplete=True, SendWhenError=True, SendWhenStalled=True)


def autorun(d, path, on):
    g = profile(d)['Gui']
    saved = path + '.autorun-saved.json'
    if on:
        if not os.path.exists(saved):   # keep the user's values from the first `on`
            json.dump({'RunDirectly': g['StartUpSettings']['RunDirectly'], 'PostActions': g['PostActions']},
                      open(saved, 'w'))
        g['StartUpSettings']['RunDirectly'] = True
        g['PostActions'] = 'ExitArknights, ExitSelf'
    else:
        old = json.load(open(saved)) if os.path.exists(saved) else {'RunDirectly': False, 'PostActions': 'None'}
        g['StartUpSettings']['RunDirectly'] = old['RunDirectly']
        g['PostActions'] = old['PostActions']
        if os.path.exists(saved):
            os.remove(saved)


def meow(d, meow_path):
    """MAA-Meow task chain -> MAA WPF task queue (same MaaCore, different field names)."""
    m = json.load(open(meow_path, encoding='utf-8'))
    prof = profile(d)
    G = prof['Gui']
    chain = {t['name']: t for t in m['taskProfiles'][0]['chain']}
    cfg = lambda n: chain[n]['config']
    q = {t['$type']: t for t in prof['TaskQueue']}

    q['StartUpTask'].update(IsEnable=chain['开始唤醒']['enabled'], AccountName=cfg('开始唤醒')['accountName'])
    G['RuntimeSettings'].update(ClientType=cfg('开始唤醒')['clientType'], StartGame=cfg('开始唤醒')['startGameEnabled'])

    c = cfg('自动公招')
    q['RecruitTask'].update(
        IsEnable=chain['自动公招']['enabled'], MaxTimes=c['maxRecruitTimes'], ExtraTagMode=int(c['selectExtraTags']),
        RefreshLevel3=c['refreshLevel3'], ForceRefresh=c['forceRefresh'], PreserveTagEnabled=c['preserveTagEnabled'],
        PreserveTagList=c['preserveTagList'],
        Level3Choose=c['chooseLevel3'], Level3Time=c['chooseLevel3Hour'] * 60 + c['chooseLevel3Min'],
        Level4Choose=c['chooseLevel4'], Level4Time=c['chooseLevel4Hour'] * 60 + c['chooseLevel4Min'],
        Level5Choose=c['chooseLevel5'], Level6Choose=c['chooseLevel6'])

    c = cfg('基建换班')
    i = q['InfrastTask']
    i.update(IsEnable=chain['基建换班']['enabled'], Mode=c['mode'], UsesOfDrones=c['usesOfDrones'],
             DormThreshold=c['dormThreshold'], DormTrustEnabled=c['dormTrustEnabled'],
             DormFilterNotStationed=c['dormFilterNotStationedEnabled'],
             OriginiumShardAutoReplenishment=c['originiumShardAutoReplenishment'],
             ReceptionMessageBoard=c['receptionMessageBoard'], ReceptionClueExchange=c['receptionClueExchange'],
             SendClue=c['receptionSendClue'], ContinueTraining=c['continueTraining'],
             FiammettaRecoveryEnabled=c['fiammettaRecoveryEnabled'],
             FiammettaTarget1=c['fiammettaTargets'][0], FiammettaTarget2=c['fiammettaTargets'][1],
             FiammettaTarget3=c['fiammettaTargets'][2],
             UsePinusSylvestris=c['usePinusSylvestris'], UsePerceptionInformation=c['usePerceptionInformation'],
             UseWorldlyPlight=c['useWorldlyPlight'], UseAbyssalHunter=c['useAbyssalHunter'],
             CustomFileType=c['defaultInfrast'], PlanSelect=c['customInfrastPlanSelect'])
    rooms = [f['first'] for f in c['facilities'] if f['second']]
    i['RoomList'] = [{'Room': r} for r in rooms] + [r for r in i['RoomList'] if r['Room'] not in rooms]

    c = cfg('理智作战')
    f = q['FightTask']
    f.update(IsEnable=chain['理智作战']['enabled'], UseMedicine=c['useMedicine'], MedicineCount=c['medicineNumber'],
             UseStone=c['useStone'], StoneCount=c['stoneNumber'], EnableTimesLimit=c['hasTimesLimited'],
             EnableTargetDrop=c['isSpecifiedDrops'], DropId=c['dropsItemId'], DropCount=c['dropsQuantity'],
             IsInventoryTarget=c['isInventoryTarget'], Series=c['series'],
             StagePlan=[c['stage1']] + c['alternateStages'], UseOptionalStage=c['useAlternateStage'],
             IsDrGrandet=c['isDrGrandet'], UseExpiringMedicine=c['useExpiringMedicine'],
             MedicineExpireDays=c['medicineExpireDays'], UseExpireMedicineForActivity=c['useExpireMedicineForActivity'],
             UseCustomAnnihilation=c['useCustomAnnihilation'], AnnihilationStage=c['annihilationStage'],
             HideUnavailableStage=c['hideUnavailableStage'], UseStoneAllowSave=c['allowUseStoneSave'],
             StageResetMode=c['stageResetMode'].capitalize(), HideSeries=c['hideSeries'],
             UseWeeklySchedule=c['useWeeklySchedule'])
    if c['hasTimesLimited']:
        f['TimesLimit'] = c['maxTimes']

    c = cfg('信用收支')
    q['MallTask'].update(IsEnable=chain['信用收支']['enabled'], VisitFriends=c['visitFriends'],
                         CreditFight=c['creditFight'], CreditFightFormation=c['creditFightFormation'],
                         Shopping=c['shopping'], FirstList=';'.join(c['buyFirst']), BlackList=';'.join(c['blacklist']),
                         ShoppingIgnoreBlackListWhenFull=c['forceShoppingIfCreditFull'],
                         OnlyBuyDiscount=c['onlyBuyDiscount'], ReserveMaxCredit=c['reserveMaxCredit'])

    c = cfg('领取奖励')
    q['AwardTask'].update(IsEnable=chain['领取奖励']['enabled'], Award=c['award'], Mail=c['mail'],
                          FreeGacha=c['freeGacha'], Orundum=c['orundum'], Mining=c['mining'],
                          SpecialAccess=c['specialAccess'])

    q['RoguelikeTask']['IsEnable'] = chain['自动肉鸽']['enabled']
    q['ReclamationTask']['IsEnable'] = chain['生息演算']['enabled']
    c = cfg('更新数据')
    q['UserDataUpdateTask'].update(IsEnable=chain['更新数据']['enabled'], UpdateOperBox=c['updateOperBox'],
                                   UpdateDepot=c['updateDepot'])

    order = ['StartUpTask', 'RecruitTask', 'InfrastTask', 'FightTask', 'MallTask', 'AwardTask',
             'RoguelikeTask', 'ReclamationTask', 'UserDataUpdateTask']
    prof['TaskQueue'] = [q[t] for t in order if t in q] + [t for t in prof['TaskQueue'] if t['$type'] not in order]

    app = m['appSettings']
    G['ThirdParty'].update(ReportToPenguin=app['reportToPenguin'] == 'true', PenguinId=app['penguinId'],
                           ReportToYituliu=app['reportToYituliu'] == 'true')
    G['ConnectSettings']['Extras']['Win32Extra']['MuteWhileRunning'] = app['muteOnGameLaunch'] == 'true'
    # Not carried over: 库存保持 (MAA-Meow only), the Android-only app settings, MAA-Meow's schedule.


def show(d):
    p = profile(d)
    g = p['Gui']
    print('profile:', d.get('Current'))
    print('tasks:', ', '.join(t['TaskType'] + ('' if t['IsEnable'] else ' (off)') for t in p['TaskQueue']))
    print('connect:', g['ConnectSettings']['Config'], g['ConnectSettings']['Extras']['Win32Extra'])
    s = g['StartUpSettings']
    print('start game:', s['StartPcClient'], s['PcClientPath'], '| run directly:', s['RunDirectly'],
          '| post actions:', g['PostActions'])
    print('MAA schedule:', [f"{t['Hour']:02}:{t['Minute']:02}" for t in d['Timers']['List'] if t['IsEnabled']] or 'off')
    print('notifications: system', d['Gui']['UseNotify'], '| external',
          [c['$type'] for c in g['ExternalNotification']['Configs']], g['ExternalNotification']['Delivery']['Enable'])


def main():
    path, cmd, args = sys.argv[1], sys.argv[2], sys.argv[3:]
    d = load(path)
    if cmd == 'show':
        return show(d)
    if cmd != 'autorun':   # autorun flips twice per run; only keep backups of real edits
        shutil.copy2(path, f'{path}.bak-{time.strftime("%Y%m%d-%H%M%S")}')
    if cmd == 'setup':
        setup(d, *args)
    elif cmd == 'autorun':
        autorun(d, path, args[0] == 'on')
    elif cmd == 'meow':
        meow(d, args[0])
    else:
        sys.exit(__doc__)
    save(path, d)
    show(d)


if __name__ == '__main__':
    main()
