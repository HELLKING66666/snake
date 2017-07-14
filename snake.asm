mov	ax, 0x07C0
mov	ds, ax		; 加载ds到ax
mov	ah, 0x01
mov	cx, 0x2000
; 环境设置
int 0x10		; 利用10号中断停止光标闪烁
mov	ax, 0x0305
mov	bx, 0x031F
int	0x16 ; 增加重复键入延迟

game_loop:
    call cls ; 清屏
    push word [snake_pos] ; 讲蛇头位置压栈保存
    mov	ah, 0x01	; 调用功能号为01的16中断判断是否有按键信号
    int	0x16
    jz keep_going	; 没有按键,则跳转到keep_going,继续移动
    mov	ah, 0x00	; 有则从缓存读取按键
    int	0x16
    jmp	update_snakepos ; 更新蛇头位置
keep_going:
    mov	al, [last_move]	; 没有按键,继续以最后方向移动
update_snakepos:
    cmp	al, 'a'
    je	left
    cmp	al, 's'
    je	down
    cmp	al, 'd'
    je	right
    cmp	al, 'w'
    jne	keep_going
up:
    dec	byte [snake_y_pos]
    jmp	move_done ; 蛇头移动完毕后跳转到move_done
left:
    dec	byte [snake_x_pos]
    jmp	move_done		 ; 蛇头移动完毕后跳转到move_done
right:
    inc	byte [snake_x_pos]
    jmp	move_done		 ; 蛇头移动完毕后跳转到move_done
down:
    inc	word [snake_y_pos]
move_done:
    mov	[last_move], al	; 保存最后移动方向
    mov	si, snake_body_pos ; 蛇身储存在寄存器si,其中si为源变址寄存器
    pop	ax 		; 原来的蛇头位置出栈以让蛇身移动
update_body: ;主要完成蛇身往之前的蛇部位前进
    mov	bx, [si]	; 将蛇身数组[0]赋值给bx
    test bx, bx		; 判断是否为蛇身
    jz	done_update	; 如果不是完成蛇身更新
    mov	[si], ax	; 迭代
    add	si, 2		; 迭代
    mov	ax, bx		; 迭代
    jmp	update_body	;
done_update:
    cmp	byte [grow_snake_flag], 1 ; 利用标识变量判断是否生长
    jne	add_zero_snake	; 为0,则跳转到add_zero_snake例程
    mov	word [si], ax	; 保存蛇尾
    mov	byte [grow_snake_flag], 0 ; 标识变量置零
    add	si, 2		; 蛇长大了
add_zero_snake:
    mov	word [si], 0x0000 ;
print_stuff:
    xor	dx, dx		; set pos to 0x0000
    call move_cursor	; move cursor
    mov	si, score_msg	; prepare to print score string
    call	print_string 	; print it
    mov	ax, [score]	; move the score into ax
    call	print_int	; print it
    mov	dx, [food_pos] 	; set dx to the food position
    call	move_cursor	; move cursor there
    mov	al, '*'		; use '*' as food symbol
    call	print_char	; print food
    mov	dx, [snake_pos]	; set dx to the snake head position
    call	move_cursor	; move there
    mov	al, '@'		; use '@' as snake head symbol
    call	print_char	; print it
    mov	si, snake_body_pos ; prepare to print snake body
snake_body_print_loop:
lodsw			; load position from the body, and increment si
test	ax, ax		; check if position is zero
jz	check_collisions ; if it was zero, move out of here
mov	dx, ax		; if not, move the position into dx
call	move_cursor	; move the cursor there
mov	al, 'o'		; use 'o' as the snake body symbol
call	print_char	; print it
jmp	snake_body_print_loop ; loop

check_collisions:
mov	bx, [snake_pos]	; move the snake head position into bx
cmp	bh, 25		; check if we are too far down
jge	game_over_hit_wall ; if yes, jump
cmp	bh, 0		; check if we are too far up
jl	game_over_hit_wall ; if yes, jump
cmp	bl, 80 ; check if we are too far to the right
jge	game_over_hit_wall ; if yes, jump
cmp	bl, 0		; check if we are too far to the left
jl	game_over_hit_wall ; if yes, jump
mov	si, snake_body_pos ; prepare to check for self-collision
check_collisions_self:
lodsw			; load position of snake body, and increment si
cmp	ax, bx		; check if head position = body position
je	game_over_hit_self ; if it is, jump
or	ax, ax		; check if position is 0x0000 (we are done searching)
jne	check_collisions_self ; if not, loop

no_collision:
mov	ax, [snake_pos]	; load snake head position into ax
cmp	ax, [food_pos]	; check if we are on the food
jne	game_loop_continued ; jump if snake didn't hit food
inc	word [score]	; if we were on food, increment score
mov	bx, 24		; set max value for random call (y-val - 1)
call	rand		; generate random value
push	dx		; save it on the stack
mov	bx, 78 ; set max value for random call
call	rand		; generate random value
pop	cx		; restore old random into cx
mov	dh, cl		; move old value into high bits of new
mov	[food_pos], dx	; save the position of the new random food
mov	byte [grow_snake_flag], 1 ; make sure snake grows
game_loop_continued:
mov	cx, 0x0002	; Sleep for 0,15 seconds (cx:dx)
mov	dx, 0x49F0	; 0x000249F0 = 150000
mov	ah, 0x86
int	0x15		; Sleep
jmp	game_loop	; loop

game_over_hit_self:
push 	self_msg
jmp	game_over

game_over_hit_wall:
push	wall_msg

game_over:
call	cls
mov	si, hit_msg
call	print_string
pop	si
call	print_string
mov	si, retry_msg
call	print_string
wait_for_r:
mov	ah, 0x00
int	0x16
cmp	al, 'r'
jne	wait_for_r
mov	word [snake_pos], 0x0F0F
and	word [snake_body_pos], 0
and	word [score], 0
mov	byte [last_move], 'd'
jmp	game_loop

; SCREEN FUNCTIONS ------------------------------------------------------------
cls:
mov	ax, 0x0700	; clear entire window (ah 0x07, al 0x00)
mov	bh, 0x0C	; light red on black
xor	cx, cx		; top left = (0,0)
mov	dx, 0x1950	; bottom right = (25, 80)
int	0x10
xor	dx, dx		; set dx to 0x0000
call	move_cursor	; move cursor
ret

move_cursor:
mov	ah, 0x02	; move to (dl, dh)
xor	bh, bh		; page 0
int 	0x10
ret

print_string_loop:
call print_char
print_string:			; print the string pointed to in si
lodsb			; load next byte from si
test	al, al		; check if high bit is set (end of string)
jns	print_string_loop	; loop if high bit was not set

print_char:			; print the char at al
and	al, 0x7F	; unset the high bit
mov	ah, 0x0E
int	0x10
ret

print_int:			; print the int in ax
push	bp		; save bp on the stack
mov	bp, sp		; set bp = stack pointer

push_digits:
xor	dx, dx		; clear dx for division
mov	bx, 10		; set bx to 10
div	bx		; divide by 10
push	dx		; store remainder on stack
test	ax, ax		; check if quotient is 0
jnz 	push_digits	; if not, loop

pop_and_print_digits:
pop	ax		; get first digit from stack
add	al, '0'		; turn it into ascii digits
call	print_char	; print it
cmp	sp, bp		; is the stack pointer is at where we began?
jne	pop_and_print_digits ; if not, loop
pop	bp		; if yes, restore bp
ret
; UTILITY FUNCTIONS -----------------------------------------------------------
rand:				; random number between 1 and bx. result in dx
mov	ah, 0x00
int	0x1A		; get clock ticks since midnight
mov	ax, dx		; move lower bits into ax for division
xor	dx, dx		; clear dx
div	bx		; divide ax by bx to get remainder in dx
inc	dx
ret

; ------------------------------------------------------------------------
;   定义消息,变量以及变量初始化
; ------------------------------------------------------------------------
; 消息MESSAGES (Encoded as 7-bit strings. Last byte is an ascii value with its
retry_msg db '! press r to retr', 0xF9 ; y
hit_msg db 'You hit', 0xA0 ; space
self_msg db 'yoursel', 0xE6 ; f
wall_msg db 'the wal', 0xEC ; l
score_msg db 'Score:', 0xA0 ; space

; 变量以及初始化
grow_snake_flag db 0
food_pos dw 0x0D0D
score dw 1
last_move db 'd'
snake_pos:
snake_x_pos db 0x0F
snake_y_pos db 0x0F
snake_body_pos dw 0x0000

; PADDING AND BOOT SIGNATURE --------------------------------------------------
times 510-($-$$) db 0
db 0x55
db 0xAA
