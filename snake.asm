main:
	mov	ax, 0x07C0 
	mov	ds, ax		; set DS to the point where code is loaded
	mov	ah, 0x01
	mov	cx, 0x2000
	int 	0x10		; clear cursor blinking

	call	clear_screen
game_loop:
	push	word [snake_pos]
	mov	ah, 0x01	; check if key available
	int	0x16
	jz	done_clear	; if not, move on
	mov	ah, 0x00	; if the was a key, remove it from buffer
	int	0x16
	jmp	update_snakepos
done_clear:
	mov	al, [last_move]
update_snakepos:
	cmp	al, 'w'	
	je	up
	cmp	al, 'a'
	je	down
	cmp	al, 'd'
	je	right
	cmp	al, 's'
	je	left
	mov	al, [last_move]
	jmp 	update_snakepos
up:
	sub	word [snake_pos], 0x0100
	jmp	move_done
down:
	sub	word [snake_pos], 0x0001
	jmp	move_done
right:
	add	word [snake_pos], 0x0001
	jmp	move_done
left:
	add	word [snake_pos], 0x0100
	jmp	move_done
move_done:
	mov	[last_move], al
	mov	si, snake_body_pos
	pop	ax
update_body:
	mov	bx, [si]
	test	bx, bx
	jz	done_update
	mov	[si], ax
	add	si, 2
	mov	ax, bx
	jmp	update_body
done_update:
	cmp	byte [grow_snake_flag], 1	
	je	grow_snake
	mov	word [si], 0x0000
	mov	[old_tail], ax
	jmp	print_stuff
grow_snake:
	mov	word [si], ax
	mov	word [si+2], 0x0000	
	mov	byte [grow_snake_flag], 0

print_stuff:
	xor	dx, dx
	call	move_cursor	
	mov	si, score_msg
	call	print_string
	mov	ax, [score]
	call	print_int
	mov	dx, [food_pos]
	call	move_cursor
	mov	al, '*'
	call	print_char	; print food
	mov	dx, [snake_pos]
	call	move_cursor
	mov	al, '@'		; print snake head
	call	print_char
	mov	dx, [old_tail]	; clear old tail char
	call	move_cursor
	mov	al, ' '
	call	print_char
	mov	si, snake_body_pos
snake_body_print_loop:
	lodsw
	test	ax, ax
	jz	check_collisions
	mov	dx, ax
	call	move_cursor
	mov	al, 'o'
	call	print_char
	jmp	snake_body_print_loop

check_collisions:
	mov	bx, [snake_pos]
	cmp	bh, 25
	jge	game_over_hit_wall
	cmp	bh, 0
	jl	game_over_hit_wall
	cmp	bl, 80
	jge	game_over_hit_wall
	cmp	bl, 0
	jl	game_over_hit_wall
	mov	si, snake_body_pos
check_collisions_self:
	lodsw
	or	ax, ax
	je	no_collision
	cmp	ax, bx
	je	game_over_hit_self
	jmp	check_collisions_self	

no_collision:
	mov	ax, [snake_pos]
	cmp	ax, [food_pos]
	jne	game_loop_continued ; jump if snake didn't hit food
	inc	word [score]
	mov	bx, 23
	call	rand
	push	dx
	mov	bx, 78
	call	rand
	pop	cx
	mov	dh, cl
	inc	dh
	inc	dl
	mov	[food_pos], dx	
	mov	byte [grow_snake_flag], 1
game_loop_continued:
	mov	cx, 0x0002	; Sleep for 0,15 seconds
	mov	dx, 0x49F0	; Sleep for 0,15 seconds
	mov	ah, 0x86
	int	0x15		; Sleep
	jmp	game_loop

game_over_hit_self:
	mov	si, hit_selv_msg
	jmp	game_over

game_over_hit_wall:
	mov	si, hit_wall_msg

game_over:
	call	clear_screen
	call	print_string
	mov	si, retry_msg
	call	print_string
wait_for_r:
	mov	ah, 0x00
	int	0x16
	cmp	al, 'r'
	jne	wait_for_r
	mov	word [snake_pos], 0x0F0F
	mov	word [snake_body_pos], 0
	mov	word [score], 0
	jmp	main

; SCREEN FUNCTIONS ------------------------------------------------------------
clear_screen:
	mov	ax, 0x0700	; clear entire window (ah 0x07, al 0x00)
	mov	bh, 0x0C	; light red on black
	xor	cx, cx		; top left = (0,0)
	mov	dx, 0x1950	; bottom right = (25, 80)
	int	0x10
	xor	dx, dx		; move cursor to 0,0
	call	move_cursor
	ret

move_cursor:
	mov	ah, 0x02	; move to (dl, dh)
	xor	bh, bh		; page 0	
	int 	0x10
	ret

print_string:			; print the string pointed to in si
	lodsb			; load next byte from si
	or	al, al		; check if byte is 0
	jz	done		; if 0, quit
	call	print_char	; print the char
	jmp	print_string	; loop
	ret

print_char:			; print the char at al
	mov	ah, 0x0E
	int	0x10
	ret

print_int:
	push	bp
	mov	bp, sp
	xor	dx, dx
	jmp	push_digits

push_digits:			; print int in ax
	mov	bx, 10
	div	bx		; divide by 10
	push	dx
	test	ax, ax
	jz	pop_and_print_digits
	xor	dx, dx
	jmp 	push_digits

pop_and_print_digits:
	pop	ax
	add	al, '0'
	call	print_char
	cmp	sp, bp
	jne	pop_and_print_digits
	pop	bp
	ret				

; UTILITY FUNCTIONS -----------------------------------------------------------
done:
	ret

rand:				; random number between 0 and bx. result in dx
	mov	ah, 0x00
	int	0x1A		; get clock ticks since midnight
	mov	ax, dx		; move lower bits into ax for division
	xor	dx, dx		; clear dx
	div	bx
	ret
	
; CONSTANTS -------------------------------------------------------------------
retry_msg db '! press r to retry.', 0
hit_selv_msg db 'You hit yourself', 0
hit_wall_msg db 'You hit the wall', 0
score_msg db 'Score: ', 0

; VARIABLES -------------------------------------------------------------------
grow_snake_flag db 0
food_pos dw 0x0D0D
score dw 1
last_move db 'd'
old_tail dw 0x0000
snake_pos dw 0x0F0F
snake_body_pos dw 0x0000

; BOOT SIGNATURE --------------------------------------------------------------
times 510-($-$$) db 0
	db 0x55
	db 0xAA
