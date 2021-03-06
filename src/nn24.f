C **********************************************************************
C *  NN24
C=**********************************************************************
C=* From: SPIDER - MODULAR IMAGE PROCESSING SYSTEM                     *
C=* Copyright (C)2003, 2014, P. A. Penczek                             *
C=*                                                                    *
C=* University of Texas - Houston Medical School                       *
C=*                                                                    *
C=* Email:  pawel.a.penczek@uth.tmc.edu                                *
C=*                                                                    *
C=* This program is free software; you can redistribute it and/or      *
C=* modify it under the terms of the GNU General Public License as     *
C=* published by the Free Software Foundation; either version 2 of the *
C=* License, or (at your option) any later version.                    *
C=*                                                                    *
C=* This program is distributed in the hope that it will be useful,    *
C=* but WITHOUT ANY WARRANTY; without even the implied warranty of     *
C=* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  *
C=* General Public License for more details.                           *
C=*                                                                    *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program; if not, write to the                      *
C=* Free Software Foundation, Inc.,                                    *
C=* 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.      *
C=*                                                                    *
C=**********************************************************************
C **********************************************************************

        SUBROUTINE NN24

        INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'
        INCLUDE 'F90ALLOC.INC'

C       DOC FILE POINTERS
        REAL, DIMENSION(:,:), POINTER          :: ANGBUF, ANGSYM

        REAL, DIMENSION(:,:), ALLOCATABLE ::      DM,SM 
        COMPLEX, ALLOCATABLE, DIMENSION(:,:,:) :: XE,XO
        INTEGER, ALLOCATABLE, DIMENSION(:,:,:) :: WE,WO

        REAL, DIMENSION(:), ALLOCATABLE        :: TEMP
        LOGICAL                                :: ANGINDOC
        CHARACTER(LEN=1)                       :: NULL = CHAR(0)

        CHARACTER(LEN=MAXNAM) :: FINPIC,FINFO,ANGDOC,FINPAT
        COMMON /F_SPEC/          FINPAT,NLET,FINPIC

        DATA  IOPIC/98/,INPIC/99/

        NILMAX = NIMAX

        CALL FILELIST(.TRUE.,INPIC,FINPAT,NLET,INUMBR,NILMAX,NANG,
     &                 'TEMPLATE FOR 2-D IMAGES',IRTFLG)
        IF (IRTFLG .NE. 0) RETURN
        CLOSE(INPIC)
        MAXNUM = MAXVAL(INUMBR(1:NANG))

C       NANG - TOTAL NUMBER OF IMAGES
        WRITE(NOUT,2001) NANG
2001    FORMAT(' NUMBER OF IMAGES: ',I7)

C       RETRIEVE ARRAY WITH ANGLES DATA IN IT
        ANGINDOC = .TRUE.
        MAXXT    = 4
        MAXYT    = MAXNUM
        CALL GETDOCDAT('ANGLES DOC',.TRUE.,ANGDOC,77,.FALSE.,MAXXT,
     &                 MAXYT,ANGBUF,IRTFLG)
        IF (IRTFLG .NE. 0) ANGINDOC = .FALSE.

C       RETRIEVE ARRAY WITH SYMMETRIES DATA IN IT
        MAXXS  = 0
        MAXSYM = 0
        CALL GETDOCDAT('SYMMETRIES DOC',.TRUE.,ANGDOC,77,.TRUE.,MAXXS,
     &                   MAXSYM,ANGSYM,IRTFLG)
        IF (IRTFLG .NE. 0)  MAXSYM=1

C       OPEN FIRST IMAGE FILE TO DETERMINE NSAM, NROW, NSL
        CALL FILGET(FINPAT,FINPIC,NLET,INUMBR(1),IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999

        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINPIC,INPIC,'O',IFORM,NSAM,NROW,NSL,
     &             MAXIM,'DUMMY',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999
        CLOSE(INPIC)

        N2   = 4*NSAM
        LSD  = N2+2-MOD(N2,2)
        NMAT = LSD*N2*N2

        IF (ANGINDOC) THEN
        
           ALLOCATE(DM(9,NANG), STAT=IRTFLG)
           IF (IRTFLG.NE.0) THEN
              CALL ERRT(46,'BP 32F, DM',IER)
              GOTO 999
           ENDIF

           CALL BUILDM(INUMBR,DM,NANG,ANGBUF(1,1),.FALSE.,SSDUM,
     &              .FALSE.,IRTFLG)
           IF (IRTFLG .NE. 0) GOTO 999
        
           IF (ASSOCIATED(ANGBUF)) DEALLOCATE(ANGBUF)
        ELSE
           ALLOCATE(DM(9,1), STAT=IRTFLG)
           IF (IRTFLG .NE. 0) THEN
              CALL ERRT(46,'BP 32F, DM',IER)
              GOTO 999
           ENDIF
        ENDIF

        IF (MAXSYM .GT. 1)  THEN
           ALLOCATE(SM(9,MAXSYM), STAT=IRTFLG)
           IF (IRTFLG.NE.0) THEN 
              CALL ERRT(46,'BP 3F, SM',IER)
              GOTO 999
           ENDIF
           CALL BUILDS(SM,MAXSYM,ANGSYM(1,1),IRTFLG)
           IF (ASSOCIATED(ANGSYM)) DEALLOCATE(ANGSYM)

       ELSE
           ALLOCATE(SM(1,1), STAT=IRTFLG)
           IF (IRTFLG.NE.0) THEN 
               CALL ERRT(46,'BP 3F, SM(1,1)',IER)
               GOTO 999
           ENDIF
        ENDIF

        ALLOCATE(XE(0:N2/2,N2,N2),WE(0:N2/2,N2,N2),WO(0:N2/2,N2,N2),
     &            XO(0:N2/2,N2,N2), STAT=IRTFLG)
        IF (IRTFLG.NE.0) THEN 
           CALL ERRT(46,'BP 32F; XE, WE, WO & XO',IER)
           GOTO 999
        ENDIF

        CALL  NN24Q(NSAM,XE,WE,XO,WO,
     &      LSD,N2,N2/2,INUMBR,DM,NANG,SM,MAXSYM,ANGINDOC,IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 999

        CALL  FILERD(FINPIC,NLETI,NULL,'RECONSTRUCTED 3D',IRTFLG) 
        IF (IRTFLG .NE. 0)  GOTO 999

        CALL  FILERD(FINPAT,NLETI,NULL,'RECONSTRUCTED EVEN 3D',IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 999
 
       CALL  FILERD(FINFO,NLETI,NULL,'RECONSTRUCTED ODD 3D',IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 999

        IFORM = 3
        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINPIC,IOPIC,'N',IFORM,LSD,N2,N2,
     &             MAXIM,'DUMMY',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 999

C       STORE FOURIER XE TEMPORARILY 
        CALL WRITEV(IOPIC,XE,LSD,N2,LSD,N2,N2)

        CLOSE(IOPIC)

C       CBE AND CBO (XE & XO) ARE LSD x N2 x N2
C       CWE AND CWO (WE & WO) ARE (LSD/2) x N2 x N2
        LSDD2 = LSD / 2
        IFORM = 3
        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINFO,IOPIC,'N',IFORM,LSDD2,N2,N2,
     &             MAXIM,'DUMMY',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 999

C       STORE WEIGHT WE TEMPORARILY 
        CALL WRITEV(IOPIC,WE,LSD/2,N2,LSD/2,N2,N2)

        CLOSE(IOPIC)

        CALL NORMN4(XE,WE,N2/2,N2)
        CALL WINDUM(XE,XE,NSAM,LSD,N2)

C       NOW XE IS READY, SYMMETRIZE IF NECESSARY
C       ADDITIONAL SYMMETRIZATION OF THE VOLUME XE IN REAL SPACE 05/03/02
        IF (MAXSYM .GT. 1)  THEN
           ALLOCATE (TEMP(NSAM*NSAM*NSAM), STAT=IRTFLG)
           IF (IRTFLG.NE.0) THEN 
              CALL ERRT(46,'BP 32F, TEMP',IER)
              GOTO 999
           ENDIF
           CALL COP(XE,TEMP,NSAM*NSAM*NSAM)

c$omp      parallel do private(i,j,k)
           DO K=1,N2
              DO J=1,N2
                 DO I=0,N2/2
                    XE(I,J,K)=CMPLX(0.0,0.0)
                 ENDDO
              ENDDO
           ENDDO

           IF (MOD(NSAM,2) .EQ. 0)  THEN
              KNX = NSAM/2-1
           ELSE
              KNX = NSAM/2
           ENDIF
           KLX = -NSAM/2
           CALL SYMVOL(TEMP,XE,KLX,KNX,KLX,KNX,KLX,KNX,SM,MAXSYM)
        ENDIF

        IFORM = 3
        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINPAT,IOPIC,'U',IFORM,NSAM,NSAM,NSAM,
     &             MAXIM,' ',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999

        CALL WRITEV(IOPIC,XE,NSAM,NSAM,NSAM,NSAM,NSAM)
        CLOSE(IOPIC)

        IFORM = 3
        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINPIC,IOPIC,'O',IFORM,LSD,N2,N2,
     &             MAXIM,' ',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999

        CALL READV(IOPIC,XE,LSD,N2,LSD,N2,N2)
        CLOSE(IOPIC)

        IFORM = 3
        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINFO,IOPIC,'O',IFORM,LSDD2,N2,N2,
     &             MAXIM,'DUMMY',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999


        CALL READV(IOPIC,WE,LSD/2,N2,LSD/2,N2,N2)
        CLOSE(IOPIC)

C       Add E+O
        CALL  ADDADA(XE,XO,NMAT)
        CALL  ADDADAI(WE,WO,NMAT/2)
        CALL  NORMN4(XE,WE,N2/2,N2)
        CALL  WINDUM(XE,XE,NSAM,LSD,N2)

C       TOTAL VOLUME IS READY
C       ADDITIONAL SYMMETRIZATION OF THE VOLUME TOTAL IN REAL SPACE 05/03/02
        IF (MAXSYM .GT. 1)  THEN
           CALL COP(XE,TEMP,NSAM*NSAM*NSAM)
c$omp      parallel do private(i,j,k)
           DO K=1,N2
              DO J=1,N2
                 DO I=0,N2/2
                    XE(I,J,K)=CMPLX(0.0,0.0)
                 ENDDO
              ENDDO
           ENDDO
           CALL SYMVOL(TEMP,XE,KLX,KNX,KLX,KNX,KLX,KNX,SM,MAXSYM)
        ENDIF

        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINPIC,IOPIC,'U',IFORM,NSAM,NSAM,NSAM,
     &             MAXIM,'DUMMY',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0)  GOTO 999

        CALL WRITEV(IOPIC,XE,NSAM,NSAM,NSAM,NSAM,NSAM)
        CLOSE(IOPIC)

        CALL  NORMN4(XO,WO,N2/2,N2)
        CALL  WINDUM(XO,XO,NSAM,LSD,N2)

C       XO VOLUME IS READY
C       ADDITIONAL SYMMETRIZATION OF THE VOLUME XO IN REAL SPACE 05/03/02
        IF (MAXSYM .GT. 1)  THEN
           CALL COP(XO,TEMP,NSAM*NSAM*NSAM)

c$omp      parallel do private(i,j,k)
           DO K=1,N2
              DO J=1,N2
                 DO I=0,N2/2
                    XO(I,J,K) = CMPLX(0.0,0.0)
                 ENDDO
              ENDDO
           ENDDO
           CALL SYMVOL(TEMP,XO,KLX,KNX,KLX,KNX,KLX,KNX,SM,MAXSYM)
        ENDIF

        MAXIM = 0
        CALL OPFILEC(0,.FALSE.,FINFO,IOPIC,'U',IFORM,NSAM,NSAM,NSAM,
     &              MAXIM,' ',.FALSE.,IRTFLG)
        IF (IRTFLG .NE. 0) GOTO 999

        CALL WRITEV(IOPIC,XO,NSAM,NSAM,NSAM,NSAM,NSAM)

        CLOSE(IOPIC)

999     CONTINUE
        IF (ALLOCATED(DM))      DEALLOCATE(DM)
        IF (ALLOCATED(SM))      DEALLOCATE(SM)
        IF (ALLOCATED(XE))      DEALLOCATE(XE)
        IF (ALLOCATED(WE))      DEALLOCATE(WE)
        IF (ALLOCATED(XO))      DEALLOCATE(XO)
        IF (ALLOCATED(WO))      DEALLOCATE(WO)
        IF (ALLOCATED(TEMP))    DEALLOCATE(TEMP)
        IF (ASSOCIATED(ANGBUF)) DEALLOCATE(ANGBUF)
        IF (ASSOCIATED(ANGSYM)) DEALLOCATE(ANGSYM)
 
        END


C       ------------------ NN24Q ----------------------------------

        SUBROUTINE  NN24Q(NS,XE,NE,XO,NO,
     &      LSD,N,N2,ILIST,DM,NANG,SM,MAXSYM,ANGINDOC,IRTFLG)
       
        INCLUDE 'CMLIMIT.INC'

        LOGICAL ::                              ANGINDOC
        LOGICAL, DIMENSION(:), ALLOCATABLE ::   RANDLIST
        INTEGER           NE(0:N2,N,N),NO(0:N2,N,N)
        COMPLEX           XE(0:N2,N,N),XO(0:N2,N,N)
        DIMENSION         ILIST(NANG)
        DIMENSION         DM(3,3,NANG),SM(3,3,MAXSYM),DMS(3,3)

        REAL,    DIMENSION(:,:), ALLOCATABLE :: PROJ
        COMPLEX, DIMENSION(:,:), ALLOCATABLE :: BI
        REAL, DIMENSION(4)                   :: ANGBUF

        CHARACTER(LEN=MAXNAM) :: FINPIC,FINPAT
        COMMON  /F_SPEC/         FINPAT,NLET,FINPIC

        DOUBLE PRECISION         PI
        LOGICAL                  ITMP

        PARAMETER (QUADPI = 3.141592653589793238462643383279502884197)
        PARAMETER (TWOPI = 2*QUADPI)

        DATA  INPROJ/99/

c$omp   parallel do private(i,j,k)
        DO    K=1,N
           DO    J=1,N
              DO    I=0,N2
                 XE(I,J,K)=CMPLX(0.0,0.0)
                 NE(I,J,K)=0.0
                 XO(I,J,K)=CMPLX(0.0,0.0)
                 NO(I,J,K)=0.0
              ENDDO
           ENDDO
        ENDDO

        ALLOCATE (PROJ(NS,NS),BI(0:N2,N),RANDLIST(NANG), STAT=IRTFLG)
        IF (IRTFLG.NE.0) THEN 
           CALL ERRT(46,'BP NF, PROJ, BI',IER)
           RETURN
        ENDIF

        RANDLIST(1:NANG/2)      = .TRUE.
        RANDLIST(NANG/2+1:NANG) = .FALSE.

        DO  K=1,NANG
           CALL  RANDOM_NUMBER(HARVEST=X)
           IORD = MIN0(NANG,MAX0(1,INT(X*NANG+0.5)))
           ITMP = RANDLIST(IORD)
           RANDLIST(IORD) = RANDLIST(K)
           RANDLIST(K)    = ITMP
        ENDDO

        DO    K=1,NANG
C          PRINT  *,' PROJECTION #',K

C          OPEN DESIRED FILE
           CALL FILGET(FINPAT,FINPIC,NLET,ILIST(K),IRTFLG)
           IF (IRTFLG .NE. 0) RETURN

           MAXIM = 0
           CALL OPFILEC(0,.FALSE.,FINPIC,INPROJ,'O',IFORM,NSAM,NSAM,NSL,
     &                   MAXIM,'DUMMY',.FALSE.,IRTFLG)
           IF (IRTFLG .NE. 0) GOTO 9999

           CALL READV(INPROJ,PROJ,NS,NS,NS,NS,1)
           CLOSE(INPROJ)

           IF (.NOT. ANGINDOC) THEN
C             GET ANGLES FROM HEADER
              ANGBUF(1) = ILIST(K)
              CALL LUNGETVALS(INPROJ,IAPLOC+1,3,ANGBUF(2),IRTFLG)
              CALL BUILDM(ILIST,DM,1,ANGBUF,.FALSE.,SSDUM,
     &              .FALSE.,IRTFLG)
              IF (IRTFLG .NE. 0) GOTO 9999
           ENDIF

           CALL PADD2(PROJ,NS,BI,LSD,N)
           INV = +1
           CALL FMRS_2(BI,N,N,INV)
c$omp parallel do private(i,j)
           DO  J=1,N
              DO  I=0,N2
                 BI(I,J)=BI(I,J)*(-1)**(I+J+1)
              ENDDO
           ENDDO
C
           DO  ISYM=1,MAXSYM
            IF(MAXSYM.GT.1)  THEN
C  symmetries, multiply matrices
             DMS=MATMUL(SM(:,:,ISYM),DM(:,:,K))
            ELSE
             DMS=DM(:,:,K)
            ENDIF
           IF (RANDLIST(K)) THEN
C,schedule(static)
c$omp parallel do private(j),shared(N,N2,JT,X,NR,BI,DMS)
            DO J=-N2+1,N2
              CALL ONELINENN(J,N,N2,XE,NE,BI,DMS)
            ENDDO
           ELSE
c$omp parallel do private(j),shared(N,N2,JT,X,NR,BI,DMS)
            DO J=-N2+1,N2
              CALL ONELINENN(J,N,N2,XO,NO,BI,DMS)
            ENDDO
           ENDIF
C   END OF SYMMETRIES LOOP
           ENDDO
C
C          END OF PROJECTIONS LOOP
        ENDDO
C       SYMMETRIZE BOTH VOLUMES
c$omp   parallel sections
c$omp   section
        CALL  SYMPLANEI(XE,NE,N2,N)
c$omp   section
        CALL  SYMPLANEI(XO,NO,N2,N)
c$omp   end parallel sections


9999    IF (ALLOCATED(RANDLIST))    DEALLOCATE (RANDLIST)
        IF (ALLOCATED(PROJ)) DEALLOCATE (PROJ)
        IF (ALLOCATED(BI))   DEALLOCATE (BI)
        END

C----------------ADDADAI ---------------------------------------

        SUBROUTINE  ADDADAI(X,Y,N)

        INTEGER  X(N),Y(N)

c$omp   parallel do private(k)
        DO  K=1,N
           X(K) = X(K)+Y(K)
        ENDDO
        END
