/* $Id$ */
/*
 * Copyright (c) 2004 demon <demon@vhost.dyndns.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
/*
 * Inspired by BOOTEASY by Serge Vakulenko <vak@kiae.su>
 */
/*
 * Copyright (c) 1997 Michael Shalayeff and Tobias Weingartner
 * Copyright (c) 2003 Tom Cosgrove <tom.cosgrove@arches-consulting.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR 
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */
/* Copyright (c) 1996 VaX#n8 (vax@linkdead.paranoia.com)
 * last edited 9 July 1996
 * many thanks to Erich Boleyn (erich@uruk.org) for putting up with
 * all my questions, and for his work on GRUB
 * You may use this code or fragments thereof in a manner consistent
 * with the other copyrights as long as you retain my pseudonym and
 * this copyright notice in the file.
 */

	.file	"boot.S"

#define	SCAN_ENTER	0x1c	/* scancode of Enter key */
#define	SCAN_F1		0x3b	/* scancode of F1 key */
#define	TIMEOUT		5	/* wait up to 5 seconds for replay */
#define	BOOTSEG		0x7c0	/* segment where we are loaded */
#define	RELOCSEG	0x7a0	/* segment where we relocate to */
#define	STACKOFF	0xfffc	/* stacks starts here, grows down */
#define	PARTSZ		16	/* each item of pt is 16 bytes long */
#define	NPART		4	/* 4 partitions */
#define DISKSNUM	0x475
#define	MBRMAGIC	0xaa55	/* MBR magic */

#define	puts(s)		movw	$s, %si;	call	msg

	.text
	.code16

	.globl	start
start:
	ljmp	$BOOTSEG, $1f		/* adjust %cs to be right */
1:
	movw	%cs, %ax		/* set up stack */
	movw	%ax, %ss
	movw	$STACKOFF, %sp

	movw	%ax, %ds		/* set up data segment */

	movw	$RELOCSEG, %ax		/* relocate */
	movw	%ax, %es
	xorw	%si, %si
	xorw	%di, %di
	movw	$0x200, %cx
	cld
	rep
	movsb

	ljmp	$RELOCSEG, $reloc	/* jump to relocated self */
reloc:
	pushw	%ds	/* set up %es and %ds */
	popw	%es	/* next boot is at same place as we are loaded */
	pushw	%cs
	popw	%ds	/* and %ds is at the %cs */

test_drv:
	testb	$0x80, %dl
	jnz	drive_ok
	movb	$0x80, %dl

drive_ok:
	movw	%dx, %bp

menu:
	movw	$pt, %di
	movw	$NPART, %cx

1:	/* menu loop */
	movb	%ch, (%di)	/* clear active flag */
	movb	4(%di), %al
	cmpb	$0x0, %al	/* unused */
	je	4f
	cmpb	$0x5, %al	/* ext DOS */
	je	4f
	cmpb	$0xf, %al	/* ext LBA */
	je	4f

	movb	$'1'+4, %al
	subb	%cl, %al
	movb	%al, prtnum

	puts(fkey)

	lea	namtab-2, %si

2:	/* name loop */
	incw	%si
	incw	%si
	movw	(%si), %bx
	orb	%bh, %bh	/* check unknown label */
	je	3f
	xorb	4(%di), %bh
	jne	2b

3:	/* end name loop */
	lea	nt(%bx), %si
	call	msg

4:	/* next */
	addw	$PARTSZ, %di
	loop	1b

	puts(def)

wait_key:
	xorb	%ah, %ah
	int	$0x1a
	movw	%dx, %di
	addw	$182*TIMEOUT/10, %di	/* ~18.2 ticks per second */
1:
	movb	$1, %ah
	int	$0x16
	jnz	3f
	xorb	%ah, %ah
	int	$0x1a
	cmpw	%di, %dx
	jb	1b

2:	/* default key */
	movb	dkey, %al
	jmp	4f

3:	/* get key */
	xorb	%ah, %ah
	int	$0x16
	shr	$8, %ax			/* move %ah to %al, %ah zero */
	cmpb	$SCAN_ENTER, %al
	je	2b
	addb	$'1'-SCAN_F1, %al

4:	/* test key */
	puts(crlf)
	cmpb	$'1', %al
	jb	menu
	cmpb	$'4', %al
	ja	menu

	movb	%al, dkey

	subb	$'1', %al
	movb	$PARTSZ, %ah
	mul	%ah
	movw	%ax, %bx
	lea	pt(%bx), %si

	cmpb	$0x0, 4(%si)
	je	menu
	cmpb	$0x5, 4(%si)
	je	menu
	cmpb	$0xf, 4(%si)
	je	menu

	movb	$0x80, (%si)		/* set active flag */


	movw	%bp, %dx
	movw	$0, %es:magic(,1)
	movw	$0x55aa, %bx
	movb	$0x41, %ah
	int	$0x13
	movw	%bp, %dx
	jc	do_chs
	cmpw	$MBRMAGIC, %bx
	jne	do_chs
	testb	$0x01, %cl
	jz	do_chs
do_lba:
	movl	8(%si), %ecx
	movl	%ecx, lba_sector
	pushw	%si
	movb	$0x42, %ah
	movw	$lba_command, %si
	int	$0x13
	popw	%si
	jnc	save
do_chs:
	movb	1(%si), %dh
	movw	2(%si), %cx
	movw	$0x201, %ax
	xorw	%bx, %bx
	int	$0x13
	jnc	save

	jmp	menu

save:
	pushw	%es
	movw	$RELOCSEG, %ax
	movw	%ax, %es
	movw	$0x301, %ax		/* write 1 sector */
	xorw	%bx, %bx		/* put it at %es:0 */
	movw	$0x1, %cx		/* cylinder 0, sector 1 */
	movw	%bp, %dx		/* drive #, head 0 */
	int	$0x13
	popw	%es

	cmpw	$MBRMAGIC, %es:magic(,1)
	jne	menu
	ljmp	$0, $BOOTSEG << 4
	/* not reached */

msg:
	pushw	%ax
	pushw	%bx
	movw	$1, %bx
1:	cld
	lodsb
	pushw	%ax
	andb	$~0x80, %al
	movb	$0xe, %ah
	int	$0x10
	popw	%ax
	testb	$0x80, %al
	jz	1b
	popw	%bx
	popw	%ax
	ret

/* messages */
crlf:	.ascii	"\r";		.byte	'\n'|0x80
fkey:	.ascii	"\r\nF"			/* runs into prtnum... */
prtnum:	.byte	'0'
	.ascii	" -";		.byte	' '|0x80
def:	.ascii	"\r\n\nDefault: F"	/* runs into dkey... */
dkey:	.byte	'?';		.byte	' '|0x80

/* namen table */
namtab:
	.byte	os_dos	-nt,	0x01
	.byte	os_dos	-nt,	0x04
	.byte	os_dos	-nt,	0x06
	.byte	os_win	-nt,	0x07		/* NT/XP */
	.byte	os_lnx	-nt,	0x83
	.byte	os_free	-nt,	0xa5
	.byte	os_open	-nt,	0xa6
	.byte	os_net	-nt,	0xa9
	.byte	os_misc	-nt,	0x00
nt:
os_dos:		.ascii	"DO";		.byte	'S'|0x80
os_win:		.ascii	"Window";	.byte	's'|0x80
os_lnx:		.ascii	"Linu";		.byte	'x'|0x80
os_free:	.ascii	"FreeBS";	.byte	'D'|0x80
os_open:	.ascii	"OpenBS";	.byte	'D'|0x80
os_net:		.ascii	"NetBS";	.byte	'D'|0x80
os_misc:	.ascii	"nonam";	.byte	'e'|0x80

	. = 0x1a8
lba_command:
	.byte	0x10		/* size of command packet */
	.byte	0x00		/* reserved */
	.word	0x0001		/* sectors to transfer */
	.word	0		/* target buffer, offset */
	.word	BOOTSEG		/* target buffer, segment */
lba_sector:
	.long	0, 0		/* sector number */

/* NT disk signature offset */ 
        . = 0x1b8
	.space 4, 0

/* partition table */
/* flag, head, sec, cyl, type, ehead, esect, ecyl, start, len */
	. = 0x1be
pt:
	.byte   0x0,0,0,0,0,0,0,0
	.long   0,0
	.byte   0x0,0,0,0,0,0,0,0
	.long   0,0
	.byte   0x0,0,0,0,0,0,0,0
	.long   0,0
	.byte   0x0,0,0,0,0,0,0,0
	.long   0,0

	. = 0x1fe
magic:	.short	MBRMAGIC
	. = 0x200
