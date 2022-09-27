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

;***********************************************************
;   THIS IS THE MAXIMUM DELAY TIME
;***********************************************************
#define totalDelayLineTime  #32#
;***********************************************************
;   THIS IS THE IO Base channel - stereo output 
;   goes in and out from IOBaseChannel and 
;   IOBaseChannel+1
;***********************************************************
#define IOBaseChannel   #1#
gkmaxdel    init $totalDelayLineTime
gidelsize init i(gkmaxdel)
gimin   init    .01
gicrossfadetime init .05
gihandle OSCinit 8000

gkcurrent_track init 0

gksaved_delay_tap_point init 0


    instr 99
SWrite strget 2
iWrite strcmp "true", SWrite


itim     date
Stim     dates     itim
Syear    strsub    Stim, 20, 24
Smonth   strsub    Stim, 4, 7
Sday     strsub    Stim, 8, 10
iday     strtod    Sday
Shor     strsub    Stim, 11, 13
Smin     strsub    Stim, 14, 16
Ssec     strsub    Stim, 17, 19
Sfilnam  sprintf  "output/%s_%s_%02d_%s_%s_%s_raw_%d.wav", Syear, Smonth, iday, Shor,Smin, Ssec, p15


kchan = $IOBaseChannel
ainputsig inch kchan

if (iWrite = 0) then
    fout Sfilnam, 8, ainputsig
endif



    endin

    instr 100
SDestIP strget 1
;prints SDestIP

SWrite strget 2
iWrite strcmp "true", SWrite
;prints SWrite

;
; yes, all this work to get a timestamp
;
itim     date
Stim     dates     itim
Syear    strsub    Stim, 20, 24
Smonth   strsub    Stim, 4, 7
Sday     strsub    Stim, 8, 10
iday     strtod    Sday
Shor     strsub    Stim, 11, 13
Smin     strsub    Stim, 14, 16
Ssec     strsub    Stim, 17, 19
Sfilnam  sprintf  "output/%s_%s_%02d_%s_%s_%s_track_%d.wav", Syear, Smonth, iday, Shor,Smin, Ssec, p15
;prints Sfilnam

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

kinput_volume init 1    ; input volume
koutput_volume init 1   ; output volume

kinput_on_off init p14  ; input on/off
koutput_on_off init 1   ; output on/off

aregenerated_signal init 0  ; regenerated signal - added to delay output * regen setting 
kregeneration_scalar init 0 ; regenerated signal scalar (see aregenerated_signal)

kdelay_tap_point init 0 ; delay point in line - update w/osc 
ktap_tempo_comp_time init 0 ; used in tap tempo
;ksaved_delay_tap_point init 0

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

kcycles timek

if (kcycles < 2) then
    OSCsend kcycles, SDestIP, iOscPort, SdelayPointOscAddress, "f", (kdelay_tap_point / (gkmaxdel - gimin)) + gimin
    OSCsend kcycles, SDestIP, iOscPort, SregenerationOscAddress, "f", kregeneration_scalar
    OSCsend kcycles, SDestIP, iOscPort, SinputToggleOscAddress, "f", kinput_on_off
    OSCsend kcycles, SDestIP, iOscPort, SoutputToggleOscAddress, "f", koutput_on_off
    OSCsend kcycles, SDestIP, iOscPort, SinputVolumeOscAddress, "f", kinput_volume
    OSCsend kcycles, SDestIP, iOscPort, SoutputVolumeOscAddress, "f", koutput_volume
    ;printks "\ntrack %f started\n", .001, ktrack
endif


kstatus, kchan, kdata1, kdata2  midiin
if(kstatus != 0) then
    ;printks "kstatus= %f, kchan = %f, kdata1 = %f, kdata2 = %f\n", 0, kstatus, kchan, kdata1,kdata2
    kmidi_input_toggled = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 48.0 && kdata2 != 0) ? 1 : 0
    kmidi_save = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 49.0 && kdata2 != 0) ? 1 : 0
    kmidi_tap = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 50.0 && kdata2 != 0) ? 1 : 0
    kmidi_output_toggled = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 51.0 && kdata2 != 0) ? 1 : 0
    kmidi_recall = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 52.0 && kdata2 != 0) ? 1 : 0
    kmidi_momentary_input_on = (gkcurrent_track == ktrack && kstatus == 144.0 && kdata1 == 53.0 && kdata2 != 0) ? 1 : 0
    kmidi_momentary_input_off = (gkcurrent_track == ktrack && ((kstatus == 128.0 && kdata1 == 53.0) || (kstatus == 144.0 && kdata1 == 53 && kdata2 == 0)))  ? 1 : 0
    ; this case covers true note off as well as 'note on with 0 velocity', which should be treated as note off according to midi standard.
endif

k0 OSClisten gihandle, StrackSelectedOscAddress, "f", kosc_track_selected
if (k0 == 1.0) then
    gkcurrent_track = kosc_track_selected
    ;printks "setting global track to %f\n", .0001, gkcurrent_track 
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
    ;printks "kosc_input_on: %f \n", .001, kosc_input_on
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

if kmidi_output_toggled == 1 then
    ;printks "midi_output_toggled - koutput_on_off is initially %f\n", .001, koutput_on_off 
    koutput_on_off = (koutput_on_off == 0 ? 1 : 0)
    OSCsend kcycles, SDestIP, 9000, SoutputToggleOscAddress, "f", koutput_on_off 
    ;printks "midi_output_toggled - koutput_on_off is now %f\n", .001, koutput_on_off 
    kmidi_output_toggled = 0
endif

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
    ;printks "krate: %f \n", .1, krate1
    ;printks "gidelsize: %f \n", .1, gidelsize
    OSCsend (krate1 / gidelsize), SDestIP, 9000, SdelayPointOscAddress, "f", (krate1 / gidelsize)
    ;printks "fader set to : %f \n", .1, (krate1 / gidelsize)
    kdelay_tap_point = krate1
    ktap_tempo_comp_time = 0
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

if (iWrite = 0) then
    fout Sfilnam, 8, aout*koutput_volume_scalar
endif

endin
</CsInstruments>

<CsScore>
i99 0 3600
i100 0 3600  "/1/fader1"  "/1/fader2"   "/1/toggle1"  "/1/toggle2"   "/1/fader3"  "/1/fader4"  "/1/push1" "/1/push2" "/1/push3"  9000 1 0 "/pager1"
i100 0 3600  "/2/fader1"  "/2/fader2"   "/2/toggle1"  "/2/toggle2"   "/2/fader3"  "/2/fader4"  "/2/push1" "/2/push2" "/2/push3"  9000 0 1 "/pager1"
i100 0 3600  "/3/fader1"  "/3/fader2"   "/3/toggle1"  "/3/toggle2"   "/3/fader3"  "/3/fader4"  "/3/push1" "/3/push2" "/3/push3"  9000 0 2 "/pager1"
i100 0 3600  "/4/fader1"  "/4/fader2"   "/4/toggle1"  "/4/toggle2"   "/4/fader3"  "/4/fader4"  "/4/push1" "/4/push2" "/4/push3"  9000 0 3 "/pager1"
;i1 0 3600  "/1/fader2"  "/1/rotary4"   "/1/toggle3"  "/1/toggle4"   "/1/rotary5"  "/1/rotary6"  "/1/push2"  9000
e
</CsScore>

</CsoundSynthesizer>
