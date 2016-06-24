main:
	mov	ax, 0x07C0 
	mov	ds, ax		; set DS to the point where code is loaded
	mov	ah, 0x01
	mov	cx, 0x2000
	int 	0x10		; clear cursor blinking

	call	clear_screen
game_loop:
	call	update_snakepos
	call	print_stuff
	call	check_collisions
	cmp	ax, 1
	je	game_over
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

game_over:
	call	clear_screen
	mov	si, game_over_msg
	call	print_string
	mov	ah, 0x0
	int	0x16
	mov	word [snake_pos], 0x0F0F
	mov	word [snake_body_pos], 0
	mov	word [score], 0
	mov	byte [last_move], 'd'
	call	clear_screen
	jmp	game_loop

; GAME HELPER FUNCTIONS -------------------------------------------------------
update_snakepos:
	call	clear_key_buffer
	push	word [snake_pos]
update_snakepos_old:
	cmp	al, 'w'	
	je	up
	cmp	al, 'a'
	je	down
	cmp	al, 'd'
	je	right
	cmp	al, 's'
	je	left
	mov	al, [last_move]
	jmp 	update_snakepos_old
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
	or	bx, bx
	je	done_update
	mov	[si], ax
	add	si, 2
	mov	ax, bx
	jmp	update_body
done_update:
	cmp	byte [grow_snake_flag], 1	
	je	grow_snake
	mov	word [si], 0x0000
	mov	[old_tail], ax
	ret
grow_snake:
	mov	word [si], ax
	mov	word [si+2], 0x0000	
	mov	byte [grow_snake_flag], 0
	ret
	
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
	or	ax, ax
	jz	done
	mov	dx, ax
	call	move_cursor
	mov	al, 'o'
	call	print_char
	jmp	snake_body_print_loop

check_collisions:
	mov	bx, [snake_pos]
	cmp	bh, 25
	jge	collision
	cmp	bh, 0
	jl	collision
	cmp	bl, 80
	jge	collision
	cmp	bl, 0
	jl	collision
	mov	si, snake_body_pos
check_collisions_self:
	lodsw
	or	ax, ax
	je	done
	cmp	ax, bx
	je	collision	
	jmp	check_collisions_self	
collision:
	mov	ax, 1
	ret

; INPUT FUNCTIONS -------------------------------------------------------------
clear_key_buffer:		; clears the key buffer,
	mov	ah, 0x01	; stores ASCII in al
	int	0x16
	jz	done
	mov	ah, 0x00
	int	0x16
	jmp	clear_key_buffer

; SCREEN FUNCTIONS ------------------------------------------------------------
clear_screen:
	mov	ax, 0x0700	; clear entire window (ah 0x07, al 0x00)
	mov	bh, 0x0D	; purple on black
	xor	cx, cx		; top left = (0,0)
	mov	dx, 0x1950	; bottom right = (25, 80)
	int	0x10
	mov	dx, 0x0000 	; move cursor to 0,0
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
	je	pop_and_print_digits
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
game_over_msg db 'Game over! press key to retry.', 0
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
