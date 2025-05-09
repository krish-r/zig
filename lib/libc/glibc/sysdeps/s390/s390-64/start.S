/* Startup code compliant to the 64 bit S/390 ELF ABI.
   Copyright (C) 2001-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   In addition to the permissions in the GNU Lesser General Public
   License, the Free Software Foundation gives you unlimited
   permission to link the compiled version of this file with other
   programs, and to distribute those programs without any restriction
   coming from the use of this file. (The GNU Lesser General Public
   License restrictions do apply in other respects; for example, they
   cover modification of the file, and distribution when not linked
   into another program.)

   Note that people who make modified versions of this file are not
   obligated to grant this special exception for their modified
   versions; it is their choice whether to do so. The GNU Lesser
   General Public License gives permission to release a modified
   version without this exception; this exception also makes it
   possible to release a modified version which carries forward this
   exception.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#include <sysdep.h>

/*
   This is the canonical entry point, usually the first thing in the text
   segment. Most registers' values are unspecified, except for:

   %r14		Contains a function pointer to be registered with `atexit'.
		This is how the dynamic linker arranges to have DT_FINI
		functions called for shared libraries that have been loaded
		before this code runs.

   %r15		The stack contains the arguments and environment:
		0(%r15)			argc
		8(%r15)			argv[0]
		...
		(8*argc)(%r15)		NULL
		(8*(argc+1))(%r15)	envp[0]
		...
					NULL
*/

	.text
	.globl _start
	.type _start,@function
_start:
	cfi_startproc
	/* Mark r14 as undefined in order to stop unwinding here!  */
	cfi_undefined (r14)
	/* Load argc and argv from stack.  */
	la	%r4,8(%r15)		# get argv
	lg	%r3,0(%r15)		# get argc

	/* Align the stack to a double word boundary.  */
	lghi	%r0,-16
	ngr	%r15,%r0

	/* Setup a stack frame and a parameter area.  */
	aghi	%r15,-176		# make room on stack
	xc	0(8,%r15),0(%r15)	# clear back-chain

	/* Set up arguments for __libc_start_main:
	   main, argc, argv, envp, _init, _fini, rtld_fini, stack_end
	   Note that envp will be determined later in __libc_start_main.
	 */
	stmg	%r14,%r15,160(%r15)	# store rtld_fini/stack_end to parameter area
	la	%r7,160(%r15)
	lghi	%r6,0			# Used to be fini.
	lghi	%r5,0			# Used to be init.

	/* Ok, now branch to the libc main routine.  */
#ifdef PIC
# ifdef SHARED
	/* Used for dynamic linked position independent executable.
	   => Scrt1.o  */
	larl	%r2,main@GOTENT		# load pointer to main
	lg	%r2,0(%r2)
# else
	/* Used for dynamic linked position dependent executable.
	   => crt1.o (glibc configured without --disable-default-pie:
	   PIC is defined)
	   Or for static linked position independent executable.
	   => rcrt1.o (only available if glibc configured without
	   --disable-default-pie: PIC is defined) */
	larl	%r2,__wrap_main
# endif
	brasl	%r14,__libc_start_main@plt
#else
	/* Used for dynamic/static linked position dependent executable.
	   => crt1.o (glibc configured with --disable-default-pie:
	   PIC and SHARED are not defined)  */
	larl	%r2,main		# load pointer to main
	brasl	%r14,__libc_start_main
#endif

	/* Crash if __libc_start_main returns.	*/
	.word	0

	cfi_endproc

#if defined PIC && !defined SHARED
	/* When main is not defined in the executable but in a shared library
	   then a wrapper is needed in crt1.o of the static-pie enabled libc,
	   because crt1.o and rcrt1.o share code and the later must avoid the
	   use of GOT relocations before __libc_start_main is called.  */
__wrap_main:
	cfi_startproc
	larl	%r1,main@GOTENT		# load pointer to main
	lg	%r1,0(%r1)
	br	%r1
	cfi_endproc
#endif

	/* Define a symbol for the first piece of initialized data.  */
	.data
	.globl __data_start
__data_start:
	.long 0
	.weak data_start
	data_start = __data_start
