.MODEL SMALL
.STACK 100H
.DATA
    msg_welcome     DB '=== ATM MACHINE SIMULATION ===$'
    msg_pin         DB 0DH,0AH,'Enter 4-digit PIN: $'
    msg_wrong       DB 0DH,0AH,'Invalid PIN! Try again.$'
    msg_blocked     DB 0DH,0AH,'Too many attempts! Card blocked.$'

    msg_menu        DB 0DH,0AH,0DH,0AH,'1. Check Balance',0DH,0AH,'2. Deposit Money',0DH,0AH,'3. Withdraw Money',0DH,0AH,'4. Change PIN',0DH,0AH,'5. Check History',0DH,0AH,'6. Exit',0DH,0AH,'Enter choice: $'

    msg_balance     DB 0DH,0AH,'Current Balance: $'
    msg_enter_amt   DB 0DH,0AH,'Enter amount: $'
    msg_invalid_amt DB 0DH,0AH,'Invalid amount!$'
    msg_min_wdraw   DB 0DH,0AH,'Minimum withdrawal is 200.$'
    msg_max_wdraw   DB 0DH,0AH,'Maximum withdrawal is 50,000.$'
    msg_mult_wdraw  DB 0DH,0AH,'Withdrawal must be in multiples of 100.$'
    msg_new_pin     DB 0DH,0AH,'Enter new 4-digit PIN: $'
    msg_pin_changed DB 0DH,0AH,'PIN changed successfully!$'
    msg_exit        DB 0DH,0AH,'Thank you for using our ATM!$'
    newline         DB 0DH,0AH,'$'
    msg_history_hdr DB 0DH,0AH,'=== TRANSACTION HISTORY ===$'
    msg_dep         DB 0DH,0AH,'Deposit: +$'
    msg_wdr         DB 0DH,0AH,'Withdraw: -$'
    msg_pin_chg     DB 0DH,0AH,'PIN Change performed$'
    msg_no_hist     DB 0DH,0AH,'No transactions recorded.$'
    msg_file_error  DB 0DH,0AH,'FATAL: File operation error!$' 

    balance         DW 10000
    pin             DW 1234
    attempts        DB 0

    MAX_HISTORY_ENTRIES EQU 10 
    HISTORY_RECORD_SIZE EQU 3
    history_data    DB MAX_HISTORY_ENTRIES DUP(0, 0, 0)
    history_count   DB 0 

    TXN_DEPOSIT     EQU 1
    TXN_WITHDRAW    EQU 2
    TXN_PIN_CHANGE  EQU 3

    ; --- FILE HANDLING DATA ---
    FILENAME        DB 'ATM.TXT', 0
    FILE_HANDLE     DW ?
    ; Data structure: balance(2 bytes) + pin(2 bytes) + history_count(1 byte) + history_data
    DATA_SIZE       EQU 2 + 2 + 1 + (MAX_HISTORY_ENTRIES * HISTORY_RECORD_SIZE) ; <-- FIX: Added 2 bytes for PIN
    FILE_BUFFER     DB DATA_SIZE DUP(?)
    ; -----------------------------

.CODE

; --- Helper Procedure to Record History ---
RECORD_HISTORY PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV AL, history_count
    CMP AL, MAX_HISTORY_ENTRIES
    JGE RH_DONE_EXIT

    ; Calculate offset: history_count * 3
    XOR AH, AH
    MOV BL, HISTORY_RECORD_SIZE
    MUL BL                  ; AX = history_count * 3
    
    LEA SI, history_data 
    ADD SI, AX              ; SI now points to the correct entry
    
    ; Store Transaction Type (Passed in CL)
    MOV [SI], CL
    INC SI
    
    ; Store Amount (Passed in DX) 
    MOV AX, DX
    MOV [SI], AX

    INC history_count

RH_DONE_EXIT:
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
RECORD_HISTORY ENDP

; --- FILE LOADING Procedure ---
LOAD_DATA PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES
    
    ; Try to Open the file
    MOV AH, 3DH
    MOV AL, 0
    LEA DX, FILENAME
    INT 21H
    JC LD_CREATE ; If file not found, create it

    MOV FILE_HANDLE, AX

    ; Read from file into buffer
    MOV AH, 3FH
    MOV BX, FILE_HANDLE
    MOV CX, DATA_SIZE
    LEA DX, FILE_BUFFER
    INT 21H
    JC LD_ERROR

    ; Close the file
    MOV AH, 3EH
    MOV BX, FILE_HANDLE
    INT 21H
    JC LD_ERROR

    ; Unpack data from buffer into variables
    LEA SI, FILE_BUFFER
    MOV AX, [SI]
    MOV balance, AX
    ADD SI, 2

    MOV AX, [SI]       ; <-- FIX: Load PIN from buffer
    MOV pin, AX        ; <-- FIX
    ADD SI, 2          ; <-- FIX

    MOV AL, [SI]
    MOV history_count, AL
    INC SI

    MOV CX, MAX_HISTORY_ENTRIES * HISTORY_RECORD_SIZE
    LEA DI, history_data
    PUSH DS
    POP ES
    CLD
    REP MOVSB           ; <-- FIX: Changed REPNZ to REP
    JMP LD_DONE

LD_CREATE:
    ; Create a new file if it doesn't exist
    MOV AH, 3CH
    MOV CX, 0
    LEA DX, FILENAME
    INT 21H
    JC LD_ERROR ; If create fails, it's a fatal error
    JMP LD_DONE

LD_ERROR:
    MOV AH, 09H
    LEA DX, msg_file_error
    INT 21H
    JMP EXIT_NO_SAVE

LD_DONE:
    POP ES
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
LOAD_DATA ENDP

; --- FILE SAVING Procedure ---
SAVE_DATA PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES
    
    ; Pack variables into the buffer
    LEA DI, FILE_BUFFER
    MOV AX, balance 
    MOV [DI], AX
    ADD DI, 2

    MOV AX, pin        ; <-- FIX: Save PIN to buffer
    MOV [DI], AX       ; <-- FIX
    ADD DI, 2          ; <-- FIX

    MOV AL, history_count 
    MOV [DI], AL
    INC DI
    
    MOV CX, MAX_HISTORY_ENTRIES * HISTORY_RECORD_SIZE
    LEA SI, history_data
    PUSH DS
    POP ES
    CLD
    REP MOVSB           ; <-- FIX: Changed REPNZ to REP

    ; Create/overwrite the file
    MOV AH, 3CH
    MOV CX, 0
    LEA DX, FILENAME
    INT 21H
    JC SD_ERROR
    MOV FILE_HANDLE, AX

    ; Write buffer to the file
    MOV AH, 40H
    MOV BX, FILE_HANDLE
    MOV CX, DATA_SIZE
    LEA DX, FILE_BUFFER
    INT 21H
    JC SD_ERROR

    ; Close the file
    MOV AH, 3EH
    MOV BX, FILE_HANDLE
    INT 21H
    JMP SD_DONE

SD_ERROR:
    MOV AH, 09H
    LEA DX, msg_file_error
    INT 21H

SD_DONE:
    POP ES
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
SAVE_DATA ENDP

MAIN PROC
    MOV AX, @DATA
    MOV DS, AX

    CALL LOAD_DATA

;--- Welcome Screen ---
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_welcome
    INT 21H

;--- PIN Check ---
PIN_CHECK:
    MOV AH, 09H
    LEA DX, msg_pin
    INT 21H

    CALL INPUT_NUMBER
    MOV BX, AX
    MOV AX, pin
    CMP AX, BX
    JE MAIN_MENU

    INC attempts
    CMP attempts, 3
    JGE BLOCKED

    MOV AH, 09H
    LEA DX, msg_wrong
    INT 21H
    JMP PIN_CHECK

BLOCKED:
    MOV AH, 09H
    LEA DX, msg_blocked
    INT 21H
    JMP EXIT_NO_SAVE

;--- Main Menu ---
MAIN_MENU:
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_menu
    INT 21H

    CALL INPUT_NUMBER

    CMP AX, 1
    JNE CHECK_2
    JMP SHOW_BAL
CHECK_2:
    CMP AX, 2
    JNE CHECK_3
    JMP DEPOSIT
CHECK_3:
    CMP AX, 3
    JNE CHECK_4
    JMP WITHDRAW
CHECK_4:
    CMP AX, 4
    JNE CHECK_5
    JMP CHANGE_PIN
CHECK_5:
    CMP AX, 5
    JNE CHECK_6
    JMP CHECK_HISTORY
CHECK_6:
    CMP AX, 6
    JNE INVALID_CHOICE
    JMP EXIT

INVALID_CHOICE:
    JMP MAIN_MENU ; Invalid choice

;--- Show Balance ---
SHOW_BAL:
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_balance
    INT 21H

    MOV AX, balance
    CALL PRINT_NUMBER
    
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU

;--- Deposit ---
DEPOSIT:
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_enter_amt
    INT 21H

    CALL INPUT_NUMBER
    CMP AX, 0
    JE MAIN_MENU ; Don't deposit zero
    
    MOV DX, AX
    MOV CL, TXN_DEPOSIT
    CALL RECORD_HISTORY
    
    ADD balance, AX
    
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU

;--- Withdraw ---
WITHDRAW:
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_enter_amt
    INT 21H

    CALL INPUT_NUMBER
    MOV BX, AX

    ; Check if multiple of 100
    MOV CX, 100
    XOR DX, DX  
    MOV AX, BX  
    DIV CX      
    CMP DX, 0   
    JNE MULT_ERR

    ; Check min and max using UNSIGNED comparisons
    CMP BX, 200
    JB MIN_ERR         ; <-- FIX: Changed JL to JB (Jump if Below)
    CMP BX, 50000
    JA MAX_ERR         ; <-- FIX: Changed JG to JA (Jump if Above)

    ; Check sufficient funds using UNSIGNED comparison
    CMP BX, balance
    JA INSUFFICIENT_FUNDS ; <-- FIX: Changed JG to JA (Jump if Above)

    ; If all checks pass, perform withdrawal
    SUB balance, BX
    
    MOV DX, BX          
    MOV CL, TXN_WITHDRAW
    CALL RECORD_HISTORY
    
    JMP MAIN_MENU

MIN_ERR:
    MOV AH, 09H
    LEA DX, msg_min_wdraw
    INT 21H
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU
MAX_ERR:
    MOV AH, 09H
    LEA DX, msg_max_wdraw
    INT 21H
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU
MULT_ERR:
    MOV AH, 09H
    LEA DX, msg_mult_wdraw
    INT 21H
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU
INSUFFICIENT_FUNDS:
    MOV AH, 09H
    LEA DX, msg_invalid_amt
    INT 21H
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU

;--- Change PIN ---
CHANGE_PIN:
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_new_pin
    INT 21H

    CALL INPUT_NUMBER
    MOV pin, AX
    
    XOR DX, DX ; No amount for PIN change
    MOV CL, TXN_PIN_CHANGE
    CALL RECORD_HISTORY

    MOV AH, 09H
    LEA DX, msg_pin_changed
    INT 21H
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU

;--- Check History ---
CHECK_HISTORY:
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_history_hdr
    INT 21H
    
    MOV AL, history_count
    CMP AL, 0
    JE CH_NO_HISTORY

    PUSH CX
    PUSH BX
    PUSH SI
    PUSH AX
    PUSH DX
    
    XOR CH, CH
    MOV CL, history_count
    
    LEA SI, history_data

CH_LOOP:
    MOV BL, [SI]    ; Get transaction type
    INC SI          
    MOV AX, [SI]    ; Get amount
    ADD SI, 2       

    CMP BL, TXN_DEPOSIT
    JE CH_DEPOSIT
    CMP BL, TXN_WITHDRAW
    JE CH_WITHDRAW
    CMP BL, TXN_PIN_CHANGE
    JE CH_PIN_CHANGE
    JMP CH_NEXT_ENTRY_LOOP

CH_DEPOSIT:
    MOV AH, 09H
    LEA DX, msg_dep
    INT 21H
    JMP CH_PRINT_AMT

CH_WITHDRAW:
    MOV AH, 09H
    LEA DX, msg_wdr
    INT 21H
    JMP CH_PRINT_AMT
    
CH_PIN_CHANGE:
    MOV AH, 09H
    LEA DX, msg_pin_chg
    INT 21H
    JMP CH_NEXT_ENTRY_LOOP ; Skip amount print

CH_PRINT_AMT:
    CALL PRINT_NUMBER

CH_NEXT_ENTRY_LOOP:
    MOV AH, 09H
    LEA DX, newline
    INT 21H
    LOOP CH_LOOP

    POP DX
    POP AX
    POP SI
    POP BX
    POP CX
    JMP CH_DONE

CH_NO_HISTORY:
    MOV AH, 09H
    LEA DX, msg_no_hist
    INT 21H

CH_DONE:
    CALL PRESS_ANY_KEY
    JMP MAIN_MENU

;--- Exit ---
EXIT:
    CALL SAVE_DATA
    
EXIT_NO_SAVE:
    CALL CLEAR_SCREEN
    MOV AH, 09H
    LEA DX, msg_exit
    INT 21H

    MOV AH, 4CH
    INT 21H
MAIN ENDP

;--- Helper Procedures ---
PRESS_ANY_KEY PROC
    PUSH AX
    PUSH DX
    MOV AH, 09H
    LEA DX, newline
    INT 21H
    MOV AH, 07H ; Get character without echo
    INT 21H
    POP DX
    POP AX
    RET
PRESS_ANY_KEY ENDP

CLEAR_SCREEN PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV AH, 06H
    XOR AL, AL
    MOV BH, 07H
    XOR CX, CX
    MOV DX, 184FH
    INT 10H
    POP DX
    POP CX
    POP BX
    POP AX
    RET
CLEAR_SCREEN ENDP

INPUT_NUMBER PROC
    PUSH BX
    PUSH CX
    PUSH DX

    XOR BX, BX      ; BX will hold the final number

READ_CHAR:
    MOV AH, 01H     ; Read character with echo
    INT 21H

    CMP AL, 0DH     ; Check for Enter key
    JE INPUT_DONE

    ; We have a digit, process it
    SUB AL, '0'     ; Convert from ASCII ('1') to value (1)
    XOR AH, AH      ; Clear AH to make AX a 16-bit number

    PUSH AX         ; Save the current digit on the stack
    
    MOV AX, BX      ; Move current total to AX for multiplication
    MOV CX, 10
    MUL CX          ; DX:AX = current total * 10 (result is in AX)
    
    POP DX          ; Get the digit we saved from the stack into DX
    ADD AX, DX      ; Add the new digit to the result
    MOV BX, AX      ; Update the running total in BX

    JMP READ_CHAR

INPUT_DONE:
    MOV AX, BX      ; The final number is in BX, return it in AX
    POP DX
    POP CX
    POP BX
    RET
INPUT_NUMBER ENDP

PRINT_NUMBER PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    XOR CX, CX
    MOV BX, 10
PN_LOOP:
    XOR DX, DX
    DIV BX
    PUSH DX
    INC CX
    CMP AX, 0
    JNE PN_LOOP
PN_PRINT:
    POP DX
    ADD DL, '0'
    MOV AH, 02H
    INT 21H
    LOOP PN_PRINT
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_NUMBER ENDP

END MAIN