;
; ""
; by 
;
;
; -B value and DMA buffer setting must be equal!
; 
; 2022.09.13:
; csound -odac2 -iadc2 -b64 -B1024 -M2 -+rtaudio=coreaudio  --strset1=10.0.0.205 --strset2=true delay-noclick-osc-midi.csd
;
;   where string #1 is the IP of source of OSC messages
; 

<CsoundSynthesizer>

<CsInstruments>
sr=44100
kr=44100
ksmps=1
nchnls=1

; no triggering of instruments
massign 0,0
pgmassign       0, 0
;minimal global vars - from old UI
#define totalDelayLineTime  #32#
#define IOBaseChannel   #1#
gkmaxdel    init $totalDelayLineTime
gidelsize init i(gkmaxdel)
gimin   init    .01
gicrossfadetime init .05
gihandle OSCinit 8000
gkcurrent_track init 0
gksaved_delay_tap_point init 0
gkquantize_tempo init 0

gaAudioSignals[] init 4

; these are just for 
gkTapPoint[] init 4
gkRegen[] init 4
gkInVol[] init 4
gkOutVol[] init 4
gkInToggle[] init 4
gkOutToggle[] init 4

pyinit
pyruni {{
tempo_dict = {}
flat_tempo_dict = {}

for x in [80,120]:
    s = []
    for y in range(1,65):
#    for y in [1,2,4,8,12,16,20,24,28,32]:
        s.append(y*60.0/x)
    tempo_dict[x] = s

for k, v in tempo_dict.items():
    for i in range(len(v)-1, 0, -1):
        if v[i] in flat_tempo_dict:
            flat_tempo_dict[v[i]].append((k, i))
        else:
            flat_tempo_dict[v[i]] = [(k, i)]


def find_match(i):
    candidates = {}
    sorted_keys = sorted(flat_tempo_dict.keys())
    for k in sorted_keys:
        v = flat_tempo_dict[k]
        if i > k:
            pass
        else:
            # am I closer to k or prev k
            pos = sorted_keys.index(k)
            if pos == 0:
                print("first one")
                candidates[k] = v
                break
            else:
                prevk = sorted_keys[pos-1]
                if abs(i-k) < abs(i-prevk):
                    candidates[k] = v
                else:
                    candidates[prevk] = flat_tempo_dict[prevk]
                break

    if len(candidates.keys()) == 0:
        candidates[sorted_keys[len(sorted_keys)-1]] = flat_tempo_dict[sorted_keys[len(sorted_keys)-1]]

    print(str(candidates))
    print(str(list(candidates.keys())[0]))
    return list(candidates.keys())[0]
}}


; handles global settings page changes
    instr 98
SDestIP strget 1
Squantize_toggle_addr = p4
iOscPort = p5
kosc_quantize_toggle init 0

kreset_1 init 0
kreset_2 init 0
kreset_3 init 0
kreset_4 init 0
kmidi_reset init 0

ktrig init 1

kcycles timeinstk

if (kcycles < 2) then
    OSCsend kcycles, SDestIP, iOscPort, Squantize_toggle_addr, "f", kosc_quantize_toggle
endif

k1  OSClisten gihandle, "/5/toggle_tempo", "f", kosc_quantize_toggle
if (k1 == 1.0) then
    ;printks "toggling tempo quantize: %f \n", .001, kosc_quantize_toggle
    gkquantize_tempo = kosc_quantize_toggle
endif

kstatus, kchan, kdata1, kdata2  midiin
if(kstatus != 0) then
    ;printks "kstatus= %f, kchan = %f, kdata1 = %f, kdata2 = %f\n", 0, kstatus, kchan, kdata1,kdata2
    kmidi_reset = ((kstatus == 128.0 && kdata1 == 63.0) || (kstatus == 144.0 && kdata1 == 63.0 && kdata2 == 0))  ? 1 : 0
    kmidi_trackdown = ((kstatus == 128.0 && kdata1 == 61.0) || (kstatus == 144.0 && kdata1 == 61.0 && kdata2 == 0))  ? 1 : 0
    kmidi_trackup = ((kstatus == 128.0 && kdata1 == 62.0) || (kstatus == 144.0 && kdata1 == 62.0 && kdata2 == 0))  ? 1 : 0
    kmidi_trackdown_with_reset = ((kstatus == 128.0 && kdata1 == 72.0) || (kstatus == 144.0 && kdata1 == 72.0 && kdata2 == 0))  ? 1 : 0
    kmidi_trackup_with_reset = ((kstatus == 128.0 && kdata1 == 73.0) || (kstatus == 144.0 && kdata1 == 73.0 && kdata2 == 0))  ? 1 : 0
    ; this case covers true note off as well as 'note on with 0 velocity', which should be treated as note off according to midi standard.
    ;printks "kmidi_reset: %f, gkcurrent_track: %f\n",  .1, kmidi_reset, gkcurrent_track
endif

    k11  OSClisten gihandle, "/1/reset","f", kreset_1
    if (k11 == 1.0 || (kmidi_reset != 0 && gkcurrent_track == 0.0)) then 
        turnoff2 100.1, 4, 0
        scoreline "i100.1 0 3600  \"/1/fader1\"  \"/1/fader2\"   \"/1/toggle1\"  \"/1/toggle2\"   \"/1/fader3\"  \"/1/fader4\"  \"/1/push1\" \"/1/push2\" \"/1/push3\"  9000 0 0 \"/pager1\" 1", ktrig
        printks "reset chan 1\n", .1
        kmidi_reset = 0
        gkcurrent_track = 0 
    endif

    k12  OSClisten gihandle, "/2/reset","f", kreset_2
    if (k12 == 1.0 || (kmidi_reset != 0 && gkcurrent_track == 1.0)) then 
        turnoff2 100.2, 4, 0
        scoreline "i100.2 0 3600  \"/2/fader1\"  \"/2/fader2\"   \"/2/toggle1\"  \"/2/toggle2\"   \"/2/fader3\"  \"/2/fader4\"  \"/2/push1\" \"/2/push2\" \"/2/push3\"  9000 0 1 \"/pager1\" 1", ktrig
        printks "reset chan 2\n", .1
        kmidi_reset = 0
        gkcurrent_track = 1
    endif

    k13  OSClisten gihandle, "/3/reset","f", kreset_3
    if (k13 == 1.0  || (kmidi_reset != 0 && gkcurrent_track == 2.0)) then 
        turnoff2 100.3, 4, 0
        scoreline "i100.3 0 3600  \"/3/fader1\"  \"/3/fader2\"   \"/3/toggle1\"  \"/3/toggle2\"   \"/3/fader3\"  \"/3/fader4\"  \"/3/push1\" \"/3/push2\" \"/3/push3\"  9000 0 2 \"/pager1\" 1", ktrig
        printks "reset chan 3\n", .1
        kmidi_reset = 0
        gkcurrent_track = 2
    endif

    k14  OSClisten gihandle, "/4/reset","f", kreset_4
    if (k14 == 1.0 || (kmidi_reset != 0 && gkcurrent_track == 3.0)) then 
        turnoff2 100.4, 4, 0
        scoreline "i100.4 0 3600  \"/4/fader1\"  \"/4/fader2\"   \"/4/toggle1\"  \"/4/toggle2\"   \"/4/fader3\"  \"/4/fader4\"  \"/4/push1\" \"/4/push2\" \"/4/push3\"  9000 0 3 \"/pager1\" 1", ktrig
        printks "reset chan 4\n", .1
        kmidi_reset = 0
        gkcurrent_track = 3
    endif


    if (kmidi_trackdown != 0.0 && gkcurrent_track > 0.0) then
        kprev_track = gkcurrent_track
        gkcurrent_track = gkcurrent_track - 1
        kone_based_track = gkcurrent_track+1
        OSCsend kcycles, SDestIP, iOscPort, "/pager1", "f", gkcurrent_track

        kmidi_trackdown = 0
    endif
    
    if (kmidi_trackup != 0.0 && gkcurrent_track < 3.0) then
        kprev_track = gkcurrent_track
        gkcurrent_track = gkcurrent_track + 1
        kone_based_track = gkcurrent_track+1
        OSCsend kcycles, SDestIP, iOscPort, "/pager1", "f", gkcurrent_track

        kmidi_trackup = 0
    endif

    if (kmidi_trackdown_with_reset != 0.0 && gkcurrent_track > 0.0) then    
        kprev_track = gkcurrent_track
        gkcurrent_track = gkcurrent_track - 1
        kone_based_track = gkcurrent_track+1
        OSCsend kcycles, SDestIP, iOscPort, "/pager1", "f", gkcurrent_track

        Sscoreline sprintfk "i100.%d 0 3600  \"/%d/fader1\"  \"/%d/fader2\"   \"/%d/toggle1\"  \"/%d/toggle2\"   \"/%d/fader3\"  \"/%d/fader4\"  \"/%d/push1\" \"/%d/push2\" \"/%d/push3\"  9000 0 %d \"/pager1\" 1 1 %d", kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, gkcurrent_track, kprev_track
        Snum sprintfk "100.%d", kone_based_track
        knum strtodk Snum


        turnoff2 knum, 4, 0
        scoreline Sscoreline, ktrig

        ; turn input off from prev track
        ; this is also the one based track...
        ;SinputToggleOscAddress sprintfk "/%d/toggle1", kprev_track+1
        ;OSCsend kcycles, SDestIP, iOscPort, SinputToggleOscAddress, "f", 0
        ;printks "sent input off to %s\n", .1, SinputToggleOscAddress


        ;printks "%s, Snum: %s, knum: %f\n", .1, Sscoreline, Snum, knum
;        printks "setting global track to %f\n", .1, gkcurrent_track 
        kmidi_trackdown_with_reset = 0
    endif
    
    if (kmidi_trackup_with_reset != 0.0 && gkcurrent_track < 3.0) then
        kprev_track = gkcurrent_track
        gkcurrent_track = gkcurrent_track + 1
        kone_based_track = gkcurrent_track+1
        OSCsend kcycles, SDestIP, iOscPort, "/pager1", "f", gkcurrent_track

        Sscoreline sprintfk "i100.%d 0 3600  \"/%d/fader1\"  \"/%d/fader2\"   \"/%d/toggle1\"  \"/%d/toggle2\"   \"/%d/fader3\"  \"/%d/fader4\"  \"/%d/push1\" \"/%d/push2\" \"/%d/push3\"  9000 0 %d \"/pager1\" 1 1 %d", kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, kone_based_track, gkcurrent_track, kprev_track

        Snum sprintfk "100.%d", kone_based_track
        knum strtodk Snum

        turnoff2 knum, 4, 0
        scoreline Sscoreline, ktrig

        ; turn input off from prev track
        ; this is also the one based track...
        ;SinputToggleOscAddress sprintfk "/%d/toggle1", kprev_track+1
        ;OSCsend kcycles, SDestIP, iOscPort, SinputToggleOscAddress, "f", 0
        ;printks "sent input off to %s\n", .1, SinputToggleOscAddress

        ;printks "%s, Snum: %s, knum: %f\n", .1, Sscoreline, Snum, knum
;        printks "setting global track to %f\n", .1, gkcurrent_track 
        kmidi_trackup_with_reset = 0
    endif


    endin

    instr 100
SDestIP strget 1
;prints SDestIP

;printks "here", 1

SdelayPointOscAddress = p4
SregenerationOscAddress = p5
SinputToggleOscAddress = p6
SoutputToggleOscAddress = p7
SinputVolumeOscAddress = p8
SoutputVolumeOscAddress = p9
StapTempoOscAddress = p10
SsaveOscAddress = p11
SrecallOscAddress = p12
iOscPort = p13
ktrack init p15
StrackSelectedOscAddress = p16
kreset_channel = p17
kapply_setting_from_track_flag = p18
kapply_setting_from_track = p19

ainputsig = 0

kcrossfade_before init 0
kcrossfade_after init 0
kcrossfade_in_progress init 0
kcrossfade_in_progress_time init 0 ; to time crossfade instr

aout init 0

kinput_volume_trigger init 0 ;
kinput_volume_triggered init 0 ;
kinput_volume_scalar init 1 ; input volume
kinput_volume_mod init 1

kinput_volume init .9    ; input volume
koutput_volume init 1   ; output volume

kinput_on_off init p14  ; input on/off
koutput_on_off init 0   ; output on/off

aregenerated_signal init 1  ; regenerated signal - added to delay output * regen setting
kregeneration_scalar init 1 ; regenerated signal scalar (see aregenerated_signal)

kdelay_tap_point init i(gkmaxdel)    ; delay point in line - update w/osc 
ktap_tempo_comp_time init 0 ; used in tap tempo

kosc_delaytime init 0
kosc_regentime init 0
kosc_input_on init 0
kosc_output_on init 0
kosc_involume init 0
kosc_outvolume init 0
kosc_push1val init 0
kosc_push2val init 0
kosc_push3val init 0
kosc_track_selected init 0


kmidi_recvd init 0
kmidi_input_toggled init 0
kmidi_output_toggled init 0
kmidi_tap init 0
kmidi_save init 0
kmidi_recall init 0
kmidi_momentary_input_on init 0
kmidi_momentary_in_progress init 0

kcycles timeinstk


if (kcycles < 2) then
    if (kreset_channel == 1) then
        if (kapply_setting_from_track_flag == 1) then
            gkTapPoint[ktrack] = gkTapPoint[kapply_setting_from_track]
            gkRegen[ktrack] = gkRegen[kapply_setting_from_track]
            gkInToggle[ktrack] = gkInToggle[kapply_setting_from_track] 
            gkOutToggle[ktrack] = gkOutToggle[kapply_setting_from_track] 
            gkInVol[ktrack] = gkInVol[kapply_setting_from_track] 
            gkOutVol[ktrack] = gkOutVol[kapply_setting_from_track] 
        endif    
        printks "resetting to globals\n", .1
        kdelay_tap_point = gkTapPoint[ktrack]
        kregeneration_scalar = gkRegen[ktrack] 
        kinput_on_off = gkInToggle[ktrack]
        koutput_on_off = gkOutToggle[ktrack]
        kinput_volume = gkInVol[ktrack]
        koutput_volume = gkOutVol[ktrack]
    else
        printks "resetting globalsi to defaults\n", .1
        gkTapPoint[ktrack] = kdelay_tap_point
        gkRegen[ktrack] = kregeneration_scalar 
        gkInToggle[ktrack] = kinput_on_off 
        gkOutToggle[ktrack] = koutput_on_off 
        gkInVol[ktrack] = kinput_volume 
        gkOutVol[ktrack] = koutput_volume 
        
    endif
    OSCsend kcycles, SDestIP, iOscPort, SdelayPointOscAddress, "f", (kdelay_tap_point / (gkmaxdel - gimin)) + gimin
    ;OSCsend kcycles, SDestIP, iOscPort, SdelayPointOscAddress, "f", 1
    OSCsend kcycles, SDestIP, iOscPort, SregenerationOscAddress, "f", kregeneration_scalar
    OSCsend kcycles, SDestIP, iOscPort, SinputToggleOscAddress, "f", kinput_on_off
    OSCsend kcycles, SDestIP, iOscPort, SoutputToggleOscAddress, "f", koutput_on_off
    OSCsend kcycles, SDestIP, iOscPort, SinputVolumeOscAddress, "f", kinput_volume
    OSCsend kcycles, SDestIP, iOscPort, SoutputVolumeOscAddress, "f", koutput_volume
    printks "\ntrack %f started - kcycles: %f\n", .001, ktrack, kcycles
endif

kstatus, kchan, kdata1, kdata2  midiin
if(kstatus != 0) then
    printks "kstatus= %f, kchan = %f, kdata1 = %f, kdata2 = %f, ch %f, gkcurrent_track: %f, ktrack: %f\n", 0, kstatus, kchan, kdata1,kdata2, p1, gkcurrent_track,  ktrack
    kmidi_input_toggled = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 48.0 && kdata2 != 0) ? 1 : 0
    kmidi_save = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 49.0 && kdata2 != 0) ? 1 : 0
    kmidi_tap = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 50.0 && kdata2 != 0) ? 1 : 0
    kmidi_output_toggled = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 51.0 && kdata2 != 0) ? 1 : 0
    kmidi_half_time = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 51.0 && kdata2 != 0) ? 1 : 0
    kmidi_double_time = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 60.0 && kdata2 != 0) ? 1 : 0
    kmidi_recall = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 52.0 && kdata2 != 0) ? 1 : 0
    kmidi_momentary_input_on = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 53.0 && kdata2 != 0) ? 1 : 0
    kmidi_momentary_input_off = (gkcurrent_track == ktrack && ((kstatus == 128.0 && kdata1 == 53.0) || (kstatus == 144.0 && kdata1 == 53 && kdata2 == 0)))  ? 1 : 0
    ; this case covers true note off as well as 'note on with 0 velocity', which should be treated as note off according to midi standard.
endif

k0 OSClisten gihandle, StrackSelectedOscAddress, "f", kosc_track_selected
if (k0 == 1.0) then
    gkcurrent_track = kosc_track_selected
    printks "setting global track to %f\n", .0001, gkcurrent_track
endif

k1  OSClisten gihandle, SdelayPointOscAddress, "f", kosc_delaytime
if (k1 == 1.0) then 
    ;printks "kosc_delaytime: %f \n", .001, kosc_delaytime
    kdelay_tap_point = (kosc_delaytime * (gkmaxdel - gimin)) + gimin
    ;printks "kdelay_tap_point: %f \n", .001, kdelay_tap_point
endif

k2  OSClisten gihandle, SregenerationOscAddress, "f", kosc_regentime
if (k2 == 1.0) then
    ;printks "kosc_regentime: %f \n", .001, kosc_regentime
    kregeneration_scalar = kosc_regentime
endif

k3  OSClisten gihandle, SinputToggleOscAddress, "f", kosc_input_on
if (k3 == 1.0) then
    printks "kosc_input_on: %f \n", .001, kosc_input_on
    kinput_on_off = kosc_input_on
endif 

if kmidi_input_toggled == 1 then
    ;printks "midi_input_toggled - kinput_on_off is initially %f\n", .001, kinput_on_off 
    kinput_on_off = (kinput_on_off == 0 ? 1 : 0)
    OSCsend kcycles, SDestIP, 9000, SinputToggleOscAddress, "f", kinput_on_off 
    ;printks "midi_input_toggled - kinput_on_off is now %f\n", .001, kinput_on_off 
    kmidi_input_toggled = 0
endif


if (kmidi_momentary_input_on == 1 && kmidi_momentary_in_progress == 0) then
    kinput_on_off = (kinput_on_off == 0 ? 1 : 0)
    kmidi_momentary_in_progress = 1
    OSCsend kcycles, SDestIP, 9000, SinputToggleOscAddress, "f", kinput_on_off 
    ;printks "on", .001
endif


if (kmidi_momentary_input_off == 1) then
    kmidi_momentary_input_on = 0
    kmidi_momentary_input_off = 0
    kinput_on_off = (kinput_on_off == 0 ? 1 : 0)
    OSCsend kcycles, SDestIP, 9000, SinputToggleOscAddress, "f", kinput_on_off 
    kmidi_momentary_in_progress = 0
    ;printks "off", .001
endif

k4  OSClisten gihandle, SoutputToggleOscAddress, "f", kosc_output_on
if (k4 == 1.0) then
    ;printks "kosc_output_on: %f \n", .001, kosc_output_on
    koutput_on_off = kosc_output_on
    kmidi_output_toggled = 0
endif

;if kmidi_output_toggled == 1 then
;    ;printks "midi_output_toggled - koutput_on_off is initially %f\n", .001, koutput_on_off 
;    koutput_on_off = (koutput_on_off == 0 ? 1 : 0)
;    OSCsend kcycles, SDestIP, 9000, SoutputToggleOscAddress, "f", koutput_on_off 
;    ;printks "midi_output_toggled - koutput_on_off is now %f\n", .001, koutput_on_off 
;    kmidi_output_toggled = 0
;endif

k5  OSClisten gihandle, SinputVolumeOscAddress, "f", kosc_involume
if (k5 == 1.0) then
    ;printks "kosc_involume: %f \n", .001, kosc_involume
    kinput_volume = kosc_involume
endif

k6  OSClisten gihandle, SoutputVolumeOscAddress, "f", kosc_outvolume
if (k6 == 1.0) then
    ;printks "kosc_outvolume: %f \n", .001, kosc_outvolume
    koutput_volume = kosc_outvolume
endif

k7  OSClisten gihandle, StapTempoOscAddress, "f", kosc_push1val
if ((k7 == 1.0 && kosc_push1val == 1.0) || kmidi_tap == 1) then
    ;printks "tap recvd: %f \n", .001, kosc_push1val
    if (ktap_tempo_comp_time > 0) kgoto tap_tempo_compare
    ktap_tempo_comp_time times
    ;printks "gkcomptime: %f \n", .1, ktap_tempo_comp_time
    kgoto tap_tempo_done
tap_tempo_compare:
    ktemptime times
    krate1 = ktemptime - ktap_tempo_comp_time
;    printks "krate: %f\n", .1, krate1
    if gkquantize_tempo == 1 then
        krate_quantized pycall1 "find_match", krate1
        krate1 = krate_quantized
        printks "quantized: %f \n", .1, krate1
    endif
;    printks "gidelsize: %f \n", .1, gidelsize
    OSCsend (krate1 / gidelsize), SDestIP, 9000, SdelayPointOscAddress, "f", (krate1 / gidelsize)
    printks "fader set to : %f on ch: %f \n", .1, (krate1 / gidelsize), p1
    kdelay_tap_point = krate1
    ktap_tempo_comp_time = 0
    krate1 = 0
tap_tempo_done:
    kmidi_tap = 0  
endif

k8  OSClisten gihandle, SsaveOscAddress, "f", kosc_push2val
if (k8 == 1.0 || kmidi_save == 1) then
    gksaved_delay_tap_point = kdelay_tap_point
    ;printks "save: saved value: %f \n", .1, (ksaved_delay_tap_point / gidelsize)
    ;printks "save: gksaved_delay_tap_point: %f \n", .001, gksaved_delay_tap_point
    kmidi_save = 0
endif

k9  OSClisten gihandle, SrecallOscAddress, "f", kosc_push3val
if (k9 == 1.0 || kmidi_recall == 1) then
    ;printks "recall: gksaved_delay_tap_point: %f \n", .001, gksaved_delay_tap_point
    ktrig times
    OSCsend ktrig, SDestIP, 9000, SdelayPointOscAddress, "f", (gksaved_delay_tap_point / gidelsize)
    kdelay_tap_point = gksaved_delay_tap_point
    ;printks "recall: kdelay_tap_point: %f \n", .001, kdelay_tap_point
    ;printks "recall: gksaved_delay_tap_point: %f \n", .001, gksaved_delay_tap_point
    kmidi_recall = 0
endif

if (kmidi_half_time == 1) then 
;    printks "half 1st:  %f \n", .001, (kdelay_tap_point)
    kdelay_tap_point = kdelay_tap_point * (((kdelay_tap_point * .5) > gimin) ? .5 : 1)
;    printks "half : %f \n", .001, (kdelay_tap_point)
    OSCsend (kdelay_tap_point  / gidelsize), SDestIP, 9000, SdelayPointOscAddress, "f", (kdelay_tap_point / gidelsize)
    kmidi_half_time = 0 
endif
if (kmidi_double_time == 1) then 
;    printks "double 1st : %f \n", .001, (kdelay_tap_point)
    kdelay_tap_point = kdelay_tap_point * (((kdelay_tap_point * 2) <= gidelsize) ? 2 : 1)
;    printks "double : %f \n", .001, (kdelay_tap_point)
    OSCsend (kdelay_tap_point  / gidelsize), SDestIP, 9000, SdelayPointOscAddress, "f", (kdelay_tap_point / gidelsize)
    kmidi_double_time = 0
endif

kinput_volume_scalar portk  kinput_on_off, .0005
koutput_volume_scalar portk  koutput_on_off, .0005

kchan = $IOBaseChannel
kchanout = $IOBaseChannel

ainputsig inch kchan
ainputsig = ainputsig * kinput_volume * kinput_volume_scalar

asig_for_delayline = (ainputsig + aregenerated_signal) * kregeneration_scalar
kactive = 0
kactive_time times

kcf = 1.0

if kcrossfade_in_progress_time > 0 && kactive_time < (kcrossfade_in_progress_time + gicrossfadetime ) then
    kactive = 1
endif 

if  ((kcrossfade_before != kdelay_tap_point && kactive == 0.0) || kactive > 0) then;
;   printks "checking....", .01
    if (kcrossfade_in_progress == 1 && kactive == 0.0) then
;       printks "event is ended %f\n", .01, acf
        kcrossfade_in_progress = 0
        kcrossfade_before = kcrossfade_after
        kcrossfade_in_progress_time = 0
        kcf = 1.0
    elseif (kcrossfade_in_progress == 1 && kactive > 0) then
;       printks "crossfading, keeping state....\n", .01
        kbegin = kcrossfade_in_progress_time
        kend = kcrossfade_in_progress_time + gicrossfadetime - .01
        kcf = (kactive_time-kbegin) / (kend-kbegin)
        if kcf > 1.0 then
            kcf = 1.0
        endif
;       printks "kactive is 1, acf is %f\n",.01, acf    
    elseif (kcrossfade_in_progress == 0) then
        ;printks "starting event....\n", .01
        kcrossfade_after = kdelay_tap_point
        kcrossfade_in_progress = 1
        kcf = 0.0
        ktemp times
        kcrossfade_in_progress_time = ktemp
    endif
endif


aout_total  delayr     gidelsize
aoutnew     deltapi     kcrossfade_after
aoutold     deltapi     kcrossfade_before
            delayw      asig_for_delayline

aout = ainputsig + (aoutnew * kcf) + (aoutold * (1.0-kcf))
aregenerated_signal = aout

out aout*koutput_volume*koutput_volume_scalar
gaAudioSignals[p15] = aout*koutput_volume_scalar
gkTapPoint[ktrack] = kdelay_tap_point 
gkRegen[ktrack] = kregeneration_scalar
gkInVol[ktrack] = kinput_volume
gkOutVol[ktrack] = koutput_volume
gkInToggle[ktrack] = kinput_on_off
gkOutToggle[ktrack] = koutput_on_off

; printks "gkTapPoint track %f, %f, kdelay_tap_point: %f \n", .1, ktrack, gkTapPoint[ktrack], kdelay_tap_point 


endin


; handles file output
    instr 101
SWrite strget 2
iWrite strcmp "true", SWrite

if (iWrite = 0) then

itim     date
Stim     dates     itim
Syear    strsub    Stim, 20, 24
Smonth   strsub    Stim, 4, 7
Sday     strsub    Stim, 8, 10
iday     strtod    Sday
Shor     strsub    Stim, 11, 13
Smin     strsub    Stim, 14, 16
Ssec     strsub    Stim, 17, 19
Srawfilename  sprintf  "output/%s_%s_%02d_%s_%s_%s_raw.wav", Syear, Smonth, iday, Shor,Smin, Ssec
SFileNames[] init 4

SFileNames[0] sprintf "output/%s_%s_%02d_%s_%s_%s_track_%d.wav", Syear, Smonth, iday, Shor,Smin, Ssec, 0
SFileNames[1] sprintf "output/%s_%s_%02d_%s_%s_%s_track_%d.wav", Syear, Smonth, iday, Shor,Smin, Ssec, 1
SFileNames[2] sprintf "output/%s_%s_%02d_%s_%s_%s_track_%d.wav", Syear, Smonth, iday, Shor,Smin, Ssec, 2
SFileNames[3] sprintf "output/%s_%s_%02d_%s_%s_%s_track_%d.wav", Syear, Smonth, iday, Shor,Smin, Ssec, 3

; raw file output
kchan = $IOBaseChannel
ainputsig inch kchan

fout Srawfilename, 8, ainputsig
fout SFileNames[0], 8, gaAudioSignals[0]
fout SFileNames[1], 8, gaAudioSignals[1]
fout SFileNames[2], 8, gaAudioSignals[2]
fout SFileNames[3], 8, gaAudioSignals[3]

endif
    endin
</CsInstruments>

<CsScore>
i98 0 3600 "/5/toggle_tempo" 9000
i100.1 0 3600  "/1/fader1"  "/1/fader2"   "/1/toggle1"  "/1/toggle2"   "/1/fader3"  "/1/fader4"  "/1/push1" "/1/push2" "/1/push3"  9000 0 0 "/pager1"
i100.2 0 3600  "/2/fader1"  "/2/fader2"   "/2/toggle1"  "/2/toggle2"   "/2/fader3"  "/2/fader4"  "/2/push1" "/2/push2" "/2/push3"  9000 0 1 "/pager1"
i100.3 0 3600  "/3/fader1"  "/3/fader2"   "/3/toggle1"  "/3/toggle2"   "/3/fader3"  "/3/fader4"  "/3/push1" "/3/push2" "/3/push3"  9000 0 2 "/pager1"
i100.4 0 3600  "/4/fader1"  "/4/fader2"   "/4/toggle1"  "/4/toggle2"   "/4/fader3"  "/4/fader4"  "/4/push1" "/4/push2" "/4/push3"  9000 0 3 "/pager1"

i101 0 3600

e
</CsScore>

</CsoundSynthesizer>
