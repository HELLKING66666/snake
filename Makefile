run: MSDOS622.img
	nasm snake.asm -o snake.com
	mount MSDOS622.img /mnt
	cp -f snake.com /mnt
	umount /mnt
	qemu-system-x86_64 -fda MSDOS622.img

clean:
	rm *.bin *.img run *.com
