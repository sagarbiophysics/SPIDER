C **********************************************************************
C
C COPYTOSTK  'CP TO STK' STACKS                    APR 15 ArDean Leith
C
C **********************************************************************
C=* Author: ArDean Leith                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-2016  Health Research Inc.,                         *
C=* Riverview Center, 150 Broadway, Suite 560, Menands, NY 12204.      *
C=* Email: spider@wadsworth.org                                        *
C=*                                                                    *
C=* SPIDER is free software; you can redistribute it and/or            *
C=* modify it under the terms of the GNU General Public License as     *
C=* published by the Free Software Foundation; either version 2 of the *
C=* License, or (at your option) any later version.                    *
C=*                                                                    *
C=* SPIDER is distributed in the hope that it will be useful,          *
C=* but WITHOUT ANY WARRANTY; without even the implied warranty of     *
C=* merchantability or fitness for a particular purpose.  See the GNU  *
C=* General Public License for more details.                           *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program. If not, see <http://www.gnu.org/licenses> *
C=*                                                                    *
C **********************************************************************
C 
C COPYTOSTK()
C                                                                      
C PURPOSE:  COPY MULTIPLE SPIDER STACKS INTO A SINGLE STACK 
C
C23456789012345678901234567890123456789012345678901234567890123456789012
C***********************************************************************

        SUBROUTINE COPYTOSTK()
 
        IMPLICIT NONE

        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'

        ! NIMAX & INUMBR COME FROM CMLIMIT.INC
 
        REAL                  :: BUF
        COMMON /IOBUF/  BUF(NBUFSIZ)

        INTEGER               :: NX,NY,NZ, LX,LY,LZ,LTYPE,NLET

        CHARACTER(LEN=MAXNAM) :: PROMPT,FILPAT,FILOLD,FILOLDS 
        CHARACTER(LEN=MAXNAM) :: FILNEW

        INTEGER               :: NILMAX, IRTFLG, NOT_USED
        INTEGER               :: NLET1,NLET2,I,IMG2GO, IMG1,IMG2
        INTEGER               :: ITYPE1,ITYPE2, LOCAT,LOCAST 
        INTEGER               :: NSTKS, ISTK, INUM, NSTACK1, NSTACK2

        LOGICAL               :: ISSTACK, BARE,WANTNEXT,MUSTGET
        LOGICAL               :: ASKNAM,WANTSTACK,FOUROK,SAYIT
        LOGICAL               :: COPYSTAT

        REAL                  :: UNUSED 

        INTEGER, PARAMETER    :: LUN1   = 20
        INTEGER, PARAMETER    :: LUN2   = 21
        INTEGER, PARAMETER    :: LUNDOC = 80

        CHARACTER, PARAMETER  :: NULL   = CHAR(0)

        FOUROK  = .TRUE.           ! FOURIER STACKS OK
        NILMAX  = NIMAX            ! FROM CMLIMIT

C       ASK FOR INPUT FILE NAME TEMPLATE AND NUMBERS
        ASKNAM = .TRUE.
        PROMPT = 'BARE STACK TEMPLATE (E.G. STK_***@)'
        CALL FILELIST(ASKNAM,LUNDOC,FILPAT,
     &                NLET,INUMBR,NILMAX, NSTKS,PROMPT,IRTFLG)
        IF (IRTFLG .NE. 0) RETURN
        !write(6,*)'nstks:',nstks
 
        LOCAT  = INDEX(FILPAT(1:NLET),'@')   
        LOCAST = INDEX(FILPAT(1:NLET),'*')

        IF (LOCAT == NLET) NLET = NLET -1   ! REMOVE TRAILING @

C       OPEN FIRST INPUT STACK TO GET SIZING NEEDED FOR OUTPUT FILE
        CALL FILGET(FILPAT,FILOLD,NLET,INUMBR(1),IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

        FILOLDS = FILOLD(1:NLET) // '@'

        !write(6,*)' filold:',nlet,filold(1:nlet)

        ASKNAM  = .FALSE.
        NSTACK1 = 1            ! CAN OPEN STACK
        CALL OPFILEC(0,ASKNAM,FILOLDS,LUN1,'O',ITYPE1,
     &               NX,NY,NZ,NSTACK1,' ',FOUROK,IRTFLG)
        IF (IRTFLG .NE. 0) RETURN
        CLOSE(LUN1)

        nlet1 = nlet + 1
        !write(6,*)'  opened filolds:',nlet1,filolds(1:nlet1)

        IMG2GO = 1
        CALL RDPRI1S(IMG2GO,NOT_USED,
     &          'INITIAL IMAGE NUMBER IN OUTPUT STACK', IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 9999

C	OPEN OUTPUT STACK
        ASKNAM  = .TRUE.
        NSTACK2 = 1               ! OPEN A STACK
        ITYPE2  = ITYPE1

        CALL OPFILEC(0,ASKNAM,FILNEW,LUN2,'U',ITYPE2,
     &          NX,NY,NZ,NSTACK2,'OUTPUT STACK (E.G. NEWSTK@)~',
     &          FOUROK,IRTFLG)
        IF (IRTFLG .NE. 0) RETURN
 
        !write(6,*)'  opened filnew:',nlet2,filnew(1:nlet2)

        WANTNEXT = .TRUE.
        MUSTGET  = .FALSE.
        SAYIT    = .TRUE.
        COPYSTAT = .TRUE.

        IMG2     = IMG2GO   ! STARTING OUTPUT IMAGE NUMBER

C       LOOP OVER ALL INPUT STACKS (1...NSTKS)
        DO I = 1,NSTKS
           ISTK = INUMBR(I)
           CALL FILGET(FILPAT,FILOLD,NLET,ISTK,IRTFLG)

           FILOLDS = FILOLD(1:NLET) // '@'
           !write(6,*)'  filolds:',nlet,filolds(1:nlet)

C          OPEN INPUT STACK
           ASKNAM  = .FALSE.
           NSTACK1 = 1            ! CAN OPEN STACK
           CALL OPFILEC(0,ASKNAM,FILOLDS,LUN1,'O',LTYPE,
     &                  LX,LY,LZ,NSTACK1,' ',FOUROK,IRTFLG)
           IF (IRTFLG .NE. 0) RETURN
           
           !write(6,*)'  opened bare stack:',filold(1:nlet), ' nstack1:',nstack1

C          MUST CONTAIN  SAME SIZE AND TYPE OF IMAGES/VOLUMES
           CALL SIZCHK(UNUSED, LX,LY,LZ,LTYPE, NX,NY,NZ,ITYPE1, IRTFLG)
           IF (IRTFLG .NE. 0) GOTO 9999

C          LOOP OVER ALL IMAGES IN THE INPUT STACK
           DO IMG1 = 1,NSTACK1

C             GET OLD STACKED IMAGE
              CALL GETOLDSTACK(LUN1,NX,IMG1,WANTNEXT,MUSTGET,
     &                         SAYIT,IRTFLG)
              IF (IRTFLG .NE. 0) EXIT

C             OPEN NEW STACKED IMAGE
              CALL GETNEWSTACK(LUN1,LUN2,COPYSTAT,NX,IMG2,IRTFLG)
              IF (IRTFLG .NE. 0) GOTO 9999

C             COPY THE DATA RECORDS
              DO IREC = 1,NY * NZ
                 CALL REDLIN(LUN1,BUF,NX,IREC)
                 CALL WRTLIN(LUN2,BUF,NX,IREC)
              ENDDO

C             INCREMENT OUTPUT IMAGE NUMBER
              IMG2 = IMG2 + 1

           ENDDO
C          CLOSE INPUT STACK
           CLOSE(LUN1)
        ENDDO
       
9999    CLOSE(LUN1)
        CLOSE(LUN2)

        END



#ifdef NEVER
        !bare    = (locat > 0 .and. locat == nlet1) ! barestack
        !write(6,*) '  bare: ',  bare
        !isstack = (NSTACK1 > 0)                     ! using a stack
        !write(6,*)' locast,locat,nlet:',locast,locat,nlet,filpat(1:nlet)
        !write(6,*)' ilist:',ilist(1)
        !write(6,*)' locast,locat,nstks:',locast,locat,nstks


C             OPEN NEXT SET OF I/O FILES, UPDATES NINDX* 
              !write(6,*)  ' CALLING nextfiles'
              CALL NEXTFILES(NINDX1,NINDX2,  ILIST1,ILIST2, 
     &                    .FALSE., LUNXM1,LUNXM2,
     &                    NGOT1,NGOT2,    NSTACK1,NSTACK2,  
     &                    LUN1,LUN1,LUN2, FILOLD,FILNEW,
     &                    IMG1,IMG2, IRTFLG)

               IF (NINDX1 > NSTACK1) EXIT   ! FINISHED 
               IF (IRTFLG .NE. 0) EXIT      ! ERROR/END OF INPUT STACK

C       OPEN FIRST INPUT FILE, DISP = 'E' DOES NOT STOP ON ERROR
#endif

