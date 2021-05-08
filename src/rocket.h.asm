;;  -*- beebasm -*-

; Rocket ZP vars.

CLEAR rocket_zp_start, zp_max
ORG rocket_zp_start
GUARD rocket_zp_reserved
.rocket_track_task_id		skip 2
.rocket_track_task_data		skip 2
.rocket_track_display_fx	skip 2
.rocket_track_zoom			skip 2
ROCKET_MAX_TRACKS = 4

.rocket_zp_end

CLEAR rocket_zp_reserved, zp_max
ORG rocket_zp_reserved
GUARD zp_max
.rocket_vsync_count		skip 2	; &9C
IF _DEBUG
.rocket_audio_flag 		skip 1	; &9E
.rocket_fast_mode		skip 1	; &9F
ELSE
.rocket_data_ptr        skip 2  ; &9E
ENDIF
