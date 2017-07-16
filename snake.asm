org 0x100
mov ax, cs
mov es, ax
mov ds, ax
mov ss, ax  ; 设置堆栈指针
mov sp, 100h - 8
; 环境设置
mov	ah, 0x01
mov	cx, 0x2000
int 0x10		; 利用10号中断停止光标闪烁
mov	ax, 0x0305
mov	bx, 0x031F
int	0x16 ; 增加重复键入延迟
call game_loop


;------------------------------------------------------------------------
;  定义消息,变量以及变量初始化
;------------------------------------------------------------------------
Scostr db 'Score: '
Scostrlen equ $ - Scostr
HitSelfstr db 'You hit yourself ! Press r to retry'
HitSelfstrlen equ $ - HitSelfstr
HitWallstr db 'You hit the wall ! Press r to retry'
HitWallstrlen equ $ - HitWallstr

; 变量以及初始化
grow_snake_flag db 0
food_pos dw 0x0D0D
score dw 0
last_move db 'd'
snake_pos:
    snake_x_pos db 0x0F
    snake_y_pos db 0x0F
    snake_body_pos dw 0x0000


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
print_stuff: ; 打印界面
    call DispScoStr ; 打印分数段
    mov	ax, [score]	; 将Score传入寄存器ax，准备调用
    call print_int	; 打印数字
    mov	dx, [food_pos] 	; 传入食物位置，准备移动光标
    call move_cursor	; 移动光标
    mov	al, '*'		; 食物'*'传入al
    call print_char	; 打印食物
    mov	dx, [snake_pos]	; 传入蛇头位置，准备移动光标
    call	move_cursor	; 移动光标
    mov	al, '@'		; 打印蛇头
    call	print_char	; 打印蛇头
    mov	si, snake_body_pos ; 传入蛇身数组位置，准备打印蛇身
snake_body_print_loop:
    lodsw			; 存取串操作lodsw（字）：AX ← [DS:(R|E)SI]、(R|E)SI ← (R|E)SI ± 2
    test	ax, ax		; 判断是够蛇身存在
    jz	check_collisions ; 蛇身没有则跳转到check_collisions
    mov	dx, ax		; 传入蛇身位置，准备移动光标到蛇身位置
    call	move_cursor	; 移动光标
    mov	al, 'o'		; 蛇身标志为'o'
    call	print_char	; 打印蛇身
    jmp	snake_body_print_loop ; 迭代操作
check_collisions:
    mov	bx, [snake_pos]	; 将蛇头位置储存在Bx
    cmp	bh, 25		; 判断是否撞到墙（下面）
    jge	game_over_hit_wall
    cmp	bh, 0		; 判断是否撞到墙（上面）
    jl	game_over_hit_wall
    cmp	bl, 80 ; 判断是否撞到墙（右面）
    jge	game_over_hit_wall
    cmp	bl, 0		; 判断是否撞到墙（左面）
    jl	game_over_hit_wall
    mov	si, snake_body_pos ; 加载蛇身位置
check_collisions_self: ; 跌代判断蛇身与蛇头位置是否相等
    lodsw  ; 加载蛇身位置并将si ++2
    cmp	ax, bx
    je	game_over_hit_self
    or	ax, ax     ; 判断是否到达蛇尾，即蛇自撞检测结束条件
    jne	check_collisions_self ; 没则继续检测
no_collision:
    mov	ax, [snake_pos]	; 加载蛇头位置
    cmp	ax, [food_pos]	; 与食物位置判断是否吃到
    jne	game_loop_continued ; 如果没吃到，则直接跳转到game_loop_continued
    inc	word [score]	; 计分器++1
    mov	bx, 24		; 初始化行随机数范围
    call rand		; 调用随机函数结果储存在dx
    push dx		; 将 xpos（dx）压栈保存
    mov	bx, 78 ; 初始化列随机数范围
    call rand		; 产生随机数ypos（dx）
    pop	cx		; 将行位置出栈于cx
    mov	dh, cl		; 保存cl（实际的行位置）
    mov	[food_pos], dx	; 更新食物位置
    mov	byte [grow_snake_flag], 1 ; 标志变量grow_snake_flag置1
game_loop_continued:
    mov	cx, 0x0002	; Sleep for 0,15 seconds (cx:dx)
    mov	dx, 0x49F0	; 0x000249F0 = 150000
    mov	ah, 0x86
    int	0x15		; Sleep
    jmp	game_loop	; loop

game_over_hit_self:
    call cls
    call DispHitSelfStr
    call wait_for_r

game_over_hit_wall:
    call cls
    call DispHitWallStr
    call wait_for_r

wait_for_r:
    mov	ah, 0x00
    int	0x16
    cmp	al, 'r'
    jne	goout
    mov	word [snake_pos], 0x0F0F
    and	word [snake_body_pos], 0
    and	word [score], 0
    mov	byte [last_move], 'd'
    jmp	game_loop

goout:
    mov ax,4c00h    ; AH=4Ch（功能号，终止进程）、AL=0（返回代码）
    int 21h         ; DOS软中断

; 屏幕功能区 ------------------------------------------------------------
cls:
	mov ah, 06h     ; 功能号(向上滚动文本显示屏幕)
	mov al, 0
	mov ch, 0
	mov cl, 0
	mov dh, 24
	mov dl, 79
	mov bh, 0ch
	int 10h ; 调用中断清屏
	ret     ; 例程返回
;
DispScoStr: ; 显示分数字符串例程
	mov ah, 13h 	; BIOS中断的功能号（显示字符串）
	mov al, 1 		; 光标放到串尾
	mov bh, 0 		; 页号 = 0
	mov bl, 0ch 	; 字符颜色=不闪（0）黑底（000）亮红字（1100）
	mov cx, Scostrlen; 串长=strlen
	mov dx, 0 		; 显示串的起始位置（0，0）：DH=行号、DL=列号
	mov bp, Scostr; ES:BP=串地址
	int 10h 		; 调用10H号显示中断
	ret				; 从例程返回

DispHitSelfStr: ; 显示自杀字符串例程
	mov ah, 13h 	; BIOS中断的功能号（显示字符串）
	mov al, 1 		; 光标放到串尾
	mov bh, 0 		; 页号 = 0
	mov bl, 0ch 	; 字符颜色=不闪（0）黑底（000）亮红字（1100）
	mov cx, HitSelfstrlen; 串长=strlen
	mov dx, 0 		; 显示串的起始位置（0，0）：DH=行号、DL=列号
	mov bp, HitSelfstr; ES:BP=串地址
	int 10h 		; 调用10H号显示中断
	ret				; 从例程返回

DispHitWallStr: ; 显示撞墙字符串例程
	mov ah, 13h 	; BIOS中断的功能号（显示字符串）
	mov al, 1 		; 光标放到串尾
	mov bh, 0 		; 页号 = 0
	mov bl, 0ch 	; 字符颜色=不闪（0）黑底（000）亮红字（1100）
	mov cx, HitWallstrlen; 串长=strlen
	mov dx, 0 		; 显示串的起始位置（0，0）：DH=行号、DL=列号
	mov bp, HitWallstr; ES:BP=串地址
	int 10h 		; 调用10H号显示中断
	ret				; 从例程返回


move_cursor:
    mov	ah, 0x02	; move to (dl, dh)
    xor	bh, bh		; page 0
    int 	0x10
    ret

print_char:			; print the char at al
    and	al, 0x7F	; unset the high bit
    mov	ah, 0x0E
    int	0x10
    ret

;-------------------------------------------------------------------------
;  打印数字例程，由print_int,push_digits,pop_and_print_digits共同完成
;-------------------------------------------------------------------------
print_int:			; 参数为ax
    push bp		;
    mov	bp, sp		;

push_digits:
    xor	dx, dx
    mov	bx, 10
    div	bx
    push dx
    test ax, ax
    jnz push_digits

pop_and_print_digits:
    pop	ax
    add	al, '0'
    call print_char
    cmp	sp, bp
    jne	pop_and_print_digits
    pop	bp
    ret

;--------------------------------------------------------------------
;  函数
;--------------------------------------------------------------------
; 随机函数， 利用功能号为10的1A中断（）产生1至bx的随机数 -> dx
rand:
    mov	ah, 0x00
    int	0x1A	   	; get clock ticks since midnight
    mov	ax, dx		; move lower bits into ax for division
    xor	dx, dx		; clear dx
    div	bx		; divide ax by bx to get remainder in dx
    inc	dx
    ret
