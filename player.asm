.include "defines.inc"

.code

PROC init_player_sprites
	LOAD_ALL_TILES $100 + SPRITE_TILE_PLAYER, unarmed_player_tiles
	LOAD_ALL_TILES $100 + SPRITE_TILE_INTERACT, interact_tiles

	jsr read_overworld_cur
	and #$3f
	cmp #MAP_CAVE_START
	beq dark
	cmp #MAP_CAVE_INTERIOR
	beq dark
	cmp #MAP_BLOCKY_PUZZLE
	beq dark
	cmp #MAP_BLOCKY_TREASURE
	beq dark

	LOAD_PTR light_player_palette
	jmp loadpal

dark:
	LOAD_PTR dark_player_palette

loadpal:
	jsr load_sprite_palette_0

	LOAD_PTR gun_palette
	jsr load_sprite_palette_2
	LOAD_PTR fire_palette
	jsr load_sprite_palette_3

	jsr update_player_sprite
	rts
.endproc


PROC update_player_sprite
	lda player_anim_frame
	lsr
	lsr
	lsr
	and #1
	sta temp

	lda player_direction
	asl
	ora temp
	asl
	asl
	tax

	lda player_y
	clc
	adc #7
	sta sprites + SPRITE_OAM_PLAYER
	sta sprites + SPRITE_OAM_PLAYER + 4

	lda walking_sprites_for_state, x
	sta sprites + SPRITE_OAM_PLAYER + 1
	lda walking_sprites_for_state + 1, x
	sta sprites + SPRITE_OAM_PLAYER + 2
	lda walking_sprites_for_state + 2, x
	sta sprites + SPRITE_OAM_PLAYER + 5
	lda walking_sprites_for_state + 3, x
	sta sprites + SPRITE_OAM_PLAYER + 6

	lda player_x
	clc
	adc #8
	sta sprites + SPRITE_OAM_PLAYER + 3
	adc #8
	sta sprites + SPRITE_OAM_PLAYER + 7

	lda interaction_type
	cmp #INTERACT_NONE
	beq nointeract

	lda interaction_sprite_y
	clc
	adc #7
	sta sprites + SPRITE_OAM_INTERACT
	sta sprites + SPRITE_OAM_INTERACT + 4
	lda #$f9
	sta sprites + SPRITE_OAM_INTERACT + 1
	lda #$fb
	sta sprites + SPRITE_OAM_INTERACT + 5
	lda #3
	sta sprites + SPRITE_OAM_INTERACT + 2
	sta sprites + SPRITE_OAM_INTERACT + 6
	lda interaction_sprite_x
	clc
	adc #8
	sta sprites + SPRITE_OAM_INTERACT + 3
	adc #8
	sta sprites + SPRITE_OAM_INTERACT + 7
	rts

nointeract:
	lda #$ff
	sta sprites + SPRITE_OAM_INTERACT
	sta sprites + SPRITE_OAM_INTERACT + 4
	rts
.endproc


PROC perform_player_move
	lda player_direction
	sta temp_direction
	lda controller
	sta temp_controller

	lda temp_controller
	and #JOY_A
	beq noactivate

	lda interaction_type
	cmp #INTERACT_NONE
	beq nointeract

	jsr activate_interaction
	jmp noactivate

nointeract:
	jsr fire_weapon

noactivate:
	lda temp_controller
	and #JOY_UP
	bne up
	lda temp_controller
	and #JOY_DOWN
	bne downpressed
	jmp checkhoriz

downpressed:
	jmp down

up:
	; Check for cave entrance
	lda entrance_x
	asl
	asl
	asl
	asl
	cmp player_x
	bne notentrance
	lda entrance_y
	asl
	asl
	asl
	asl
	cmp player_y
	bne notentrance
	jmp transitionup
notentrance:
	; Check for top of map
	ldy player_y
	bne nottopbounds
	jmp transitionup
nottopbounds:
	lda #DIR_UP
	sta temp_direction
	; Collision detection
	tya
	and #15
	bne noupcollide
	jsr read_collision_up
	bne noupcollide
	ldx player_x
	txa
	and #15
	cmp #8
	bcc upsnapleft
	jmp upsnapright
upmoveinvalid:
	lda player_up_tile
	jsr check_for_interactive_tile
	cmp #INTERACT_NONE
	beq upnotinteract
	sta interaction_type
	jsr get_player_tile
	stx interaction_tile_x
	sty interaction_tile_y
	dey
	dey
	jsr set_interaction_pos
upnotinteract:
	jmp checkhoriz
upsnapleft:
	lda temp_controller
	and #JOY_LEFT | JOY_RIGHT
	bne upmoveinvalid
	jsr read_collision_up_direct
	beq upmoveinvalid
	lda temp_controller
	and #(~JOY_UP) & $ff
	sta temp_controller
	jmp left
upsnapright:
	lda controller
	and #JOY_LEFT | JOY_RIGHT
	bne upmoveinvalid
	jsr read_collision_right
	beq upmoveinvalid
	jsr read_collision_up_right
	beq upmoveinvalid
	lda temp_controller
	and #(~JOY_UP) & $ff
	sta temp_controller
	jmp right
noupcollide:
	; Move OK
	ldy player_y
	dey
	sty player_y
	lda #DIR_RUN_UP
	sta player_direction
	lda #1
	sta arg4
	jmp checkhoriz

down:
	; Check for bottom of map
	ldy player_y
	cpy #(MAP_HEIGHT - 1) * 16
	bcc notbotbounds
	jmp transitiondown
notbotbounds:
	lda #DIR_DOWN
	sta temp_direction
	; Collision detection
	tya
	and #15
	bne nodowncollide
	jsr read_collision_down
	bne nodowncollide
	ldx player_x
	txa
	and #15
	cmp #8
	bcc downsnapleft
	jmp downsnapright
downmoveinvalid:
	lda player_down_tile
	jsr check_for_interactive_tile
	cmp #INTERACT_NONE
	beq downnotinteract
	sta interaction_type
	jsr get_player_tile
	stx interaction_tile_x
	sty interaction_tile_y
	iny
	iny
	jsr set_interaction_pos
downnotinteract:
	jmp checkhoriz
downsnapleft:
	lda temp_controller
	and #JOY_LEFT | JOY_RIGHT
	bne downmoveinvalid
	jsr read_collision_down_direct
	beq downmoveinvalid
	lda temp_controller
	and #(~JOY_UP) & $ff
	sta temp_controller
	jmp left
downsnapright:
	lda controller
	and #JOY_LEFT | JOY_RIGHT
	bne downmoveinvalid
	jsr read_collision_right
	beq downmoveinvalid
	jsr read_collision_down_right
	beq downmoveinvalid
	lda temp_controller
	and #(~JOY_UP) & $ff
	sta temp_controller
	jmp right
nodowncollide:
	; Move OK
	ldy player_y
	iny
	sty player_y
	lda #DIR_RUN_DOWN
	sta player_direction
	lda #1
	sta arg4
	jmp checkhoriz

checkhoriz:
	lda temp_controller
	and #JOY_LEFT
	bne left
	lda temp_controller
	and #JOY_RIGHT
	bne rightpressed
	jmp movedone

rightpressed:
	jmp right

left:
	; Check for left of map
	ldx player_x
	bne notleftbounds
	jmp transitionleft
notleftbounds:
	lda #DIR_LEFT
	sta temp_direction
	; Collision detection
	txa
	and #15
	bne noleftcollide
	jsr read_collision_left
	bne noleftcollide
	ldx player_y
	txa
	and #15
	cmp #8
	bcc leftsnaptop
	jmp leftsnapbot
leftmoveinvalid:
	lda player_left_tile
	jsr check_for_interactive_tile
	cmp #INTERACT_NONE
	beq leftnotinteract
	sta interaction_type
	jsr get_player_tile
	stx interaction_tile_x
	dex
	dex
	sty interaction_tile_y
	jsr set_interaction_pos
leftnotinteract:
	jmp movedone
leftsnaptop:
	lda temp_controller
	and #JOY_UP | JOY_DOWN
	bne leftmoveinvalid
	jsr read_collision_left_direct
	beq leftmoveinvalid
	lda temp_controller
	and #(~JOY_LEFT) & $ff
	sta temp_controller
	jmp up
leftsnapbot:
	lda controller
	and #JOY_UP | JOY_DOWN
	bne leftmoveinvalid
	jsr read_collision_down
	beq leftmoveinvalid
	jsr read_collision_left_bottom
	beq leftmoveinvalid
	lda temp_controller
	and #(~JOY_LEFT) & $ff
	sta temp_controller
	jmp down
noleftcollide:
	; Move OK
	ldx player_x
	dex
	stx player_x
	lda #DIR_RUN_LEFT
	sta player_direction
	lda #1
	sta arg4
	jmp movedone

right:
	; Check for right of map
	ldx player_x
	cpx #(MAP_WIDTH - 1) * 16
	bcc notrightbounds
	jmp transitionright
notrightbounds:
	lda #DIR_RIGHT
	sta temp_direction
	; Collision detection
	txa
	and #15
	bne norightcollide
	jsr read_collision_right
	bne norightcollide
	ldx player_y
	txa
	and #15
	cmp #8
	bcc rightsnaptop
	jmp rightsnapbot
rightmoveinvalid:
	lda player_right_tile
	jsr check_for_interactive_tile
	cmp #INTERACT_NONE
	beq rightnotinteract
	sta interaction_type
	jsr get_player_tile
	stx interaction_tile_x
	inx
	inx
	sty interaction_tile_y
	jsr set_interaction_pos
rightnotinteract:
	jmp movedone
rightsnaptop:
	lda temp_controller
	and #JOY_UP | JOY_DOWN
	bne rightmoveinvalid
	jsr read_collision_right_direct
	beq rightmoveinvalid
	lda temp_controller
	and #(~JOY_RIGHT) & $ff
	sta temp_controller
	jmp up
rightsnapbot:
	lda controller
	and #JOY_UP | JOY_DOWN
	bne rightmoveinvalid
	jsr read_collision_down
	beq rightmoveinvalid
	jsr read_collision_right_bottom
	beq rightmoveinvalid
	lda temp_controller
	and #(~JOY_RIGHT) & $ff
	sta temp_controller
	jmp down
norightcollide:
	; Move OK
	ldx player_x
	inx
	stx player_x
	lda #DIR_RUN_RIGHT
	sta player_direction
	lda #1
	sta arg4
	jmp movedone

movedone:
	; Animate player if moving
	lda arg4
	beq notmoving

	lda #INTERACT_NONE
	sta interaction_type

	inc player_anim_frame
	jmp moveanimdone

notmoving:
	lda #7
	sta player_anim_frame
	lda temp_direction
	and #3
	sta player_direction

moveanimdone:
	lda #0
	rts

transitionleft:
	jsr fade_out
	dec cur_screen_x
	lda #(MAP_WIDTH - 1) * 16
	sta player_x
	lda #DIR_LEFT
	sta player_direction
	lda #1
	rts

transitionright:
	jsr fade_out
	inc cur_screen_x
	lda #0
	sta player_x
	lda #DIR_RIGHT
	sta player_direction
	lda #1
	rts

transitionup:
	jsr fade_out
	dec cur_screen_y
	lda #(MAP_HEIGHT - 1) * 16
	sta player_y
	lda #DIR_UP
	sta player_direction
	lda #1
	rts

transitiondown:
	jsr fade_out

	jsr read_overworld_cur
	and #$3f
	cmp #MAP_CAVE_INTERIOR
	bne notcaveexit

	jsr read_overworld_down
	and #$3f
	cmp #MAP_FOREST
	bne notcaveexit

	; Exiting cave, place player at cave entrance
	inc cur_screen_y
	jsr prepare_map_gen
	jsr gen_forest
	lda top_wall_right_extent
	asl
	asl
	asl
	asl
	sta player_y
	lda top_opening_pos
	clc
	adc #1
	asl
	asl
	asl
	asl
	sta player_x
	lda #DIR_DOWN
	sta player_direction
	lda #1
	rts

notcaveexit:
	; Normal exit down
	inc cur_screen_y
	lda #0
	sta player_y
	lda #DIR_DOWN
	sta player_direction
	lda #1
	rts
.endproc


PROC update_player_surroundings
	lda player_x
	lsr
	lsr
	lsr
	lsr
	adc #0 ; Round to nearest
	asl
	sta arg0

	lda player_y
	lsr
	lsr
	lsr
	lsr
	adc #0 ; Round to nearest
	asl
	sta arg1

	ldx arg0
	dex
	ldy arg1
	jsr set_ppu_addr_to_coord
	lda PPUDATA
	lda PPUDATA
	sta player_left_tile
	lda PPUDATA
	lda PPUDATA
	lda PPUDATA
	sta player_right_tile

	ldx arg0
	ldy arg1
	dey
	jsr set_ppu_addr_to_coord
	lda PPUDATA
	lda PPUDATA
	sta player_up_tile

	ldx arg0
	ldy arg1
	iny
	iny
	jsr set_ppu_addr_to_coord
	lda PPUDATA
	lda PPUDATA
	sta player_down_tile

	rts
.endproc


PROC get_player_tile
	lda player_x
	lsr
	lsr
	lsr
	lsr
	adc #0 ; Round to nearest
	tax

	lda player_y
	lsr
	lsr
	lsr
	lsr
	adc #0 ; Round to nearest
	tay

	rts
.endproc


PROC check_for_interactive_tile
	and #$fc
	sta temp
	ldx #0
loop:
	lda interactive_tile_values, x
	cmp temp
	beq found
	inx
	cpx #4
	bne loop

	lda #INTERACT_NONE
	rts

found:
	lda interactive_tile_types, x
	cmp #INTERACT_NONE
	bne ok
	rts
ok:
	sta arg0
	pha

	asl
	tax
	lda interaction_descriptors, x
	sta ptr
	lda interaction_descriptors + 1, x
	sta ptr + 1
	ldy #INTERACT_DESC_IS_VALID
	lda (ptr), y
	sta temp
	ldy #INTERACT_DESC_IS_VALID + 1
	lda (ptr), y
	sta temp + 1

	jsr get_player_tile
	lda arg0
	jsr call_temp
	bne invalid

	pla
	rts

invalid:
	pla
	lda #INTERACT_NONE
	rts
.endproc


PROC set_interaction_pos
	txa
	asl
	asl
	asl
	asl
	sta interaction_sprite_x

	tya
	asl
	asl
	asl
	asl
	sta interaction_sprite_y

	rts
.endproc


PROC fire_weapon
	rts
.endproc


PROC activate_interaction
	lda interaction_type
	cmp #INTERACT_NONE
	bne ok
	rts

ok:
	asl
	tax
	lda interaction_descriptors, x
	sta ptr
	lda interaction_descriptors + 1, x
	sta ptr + 1
	ldy #INTERACT_DESC_ACTIVATE
	lda (ptr), y
	sta temp
	ldy #INTERACT_DESC_ACTIVATE + 1
	lda (ptr), y
	sta temp + 1

	jsr get_player_tile
	lda interaction_type
	jsr call_temp

	lda #INTERACT_NONE
	sta interaction_type
	rts
.endproc


PROC always_interactable
	lda #0
	rts
.endproc


.zeropage
VAR player_x
	.byte 0
VAR player_y
	.byte 0
VAR player_direction
	.byte 0
VAR player_anim_frame
	.byte 0

VAR player_left_tile
	.byte 0
VAR player_right_tile
	.byte 0
VAR player_up_tile
	.byte 0
VAR player_down_tile
	.byte 0

VAR interaction_type
	.byte 0
VAR interaction_sprite_x
	.byte 0
VAR interaction_sprite_y
	.byte 0
VAR interaction_tile_x
	.byte 0
VAR interaction_tile_y
	.byte 0


.bss
VAR temp_direction
	.byte 0
VAR temp_controller
	.byte 0

VAR interactive_tile_types
	.byte 0, 0, 0, 0
VAR interactive_tile_values
	.byte 0, 0, 0, 0


.data
VAR walking_sprites_for_state
	; Up
	.byte $1c + 1, $00
	.byte $1e + 1, $00
	.byte $1c + 1, $00
	.byte $1e + 1, $00
	; Left
	.byte $0a + 1, $40
	.byte $08 + 1, $40
	.byte $0a + 1, $40
	.byte $08 + 1, $40
	; Right
	.byte $08 + 1, $00
	.byte $0a + 1, $00
	.byte $08 + 1, $00
	.byte $0a + 1, $00
	; Down
	.byte $18 + 1, $00
	.byte $1a + 1, $00
	.byte $18 + 1, $00
	.byte $1a + 1, $00
	; Run Up
	.byte $10 + 1, $00
	.byte $12 + 1, $00
	.byte $14 + 1, $00
	.byte $16 + 1, $00
	; Run Left
	.byte $0a + 1, $40
	.byte $08 + 1, $40
	.byte $0e + 1, $40
	.byte $0c + 1, $40
	; Run Right
	.byte $08 + 1, $00
	.byte $0a + 1, $00
	.byte $0c + 1, $00
	.byte $0e + 1, $00
	; Run Down
	.byte $00 + 1, $00
	.byte $02 + 1, $00
	.byte $04 + 1, $00
	.byte $06 + 1, $00

VAR dark_player_palette
	.byte $0f, $2d, $37, $07
VAR light_player_palette
	.byte $0f, $0f, $37, $07

VAR gun_palette
	.byte $0f, $00, $10, $20
VAR fire_palette
	.byte $0f, $06, $16, $37

VAR interaction_descriptors
	.word starting_chest_descriptor

TILES unarmed_player_tiles, 2, "tiles/characters/player/unarmed.chr", 32
TILES interact_tiles, 2, "tiles/interact.chr", 8
