
C **********************************************************************
C=*                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-2012  Health Research Inc.,                         *
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
C  ORIENT(LUN1,LUN2,NSAM,NROW,NSLICE,IRTFLG)
C
C  PARAMETERS: LUN1,LUN2   IO UNITS                             (INPUT)
C              NSAM        X DIMENSIONS                         (INPUT)
C              NROW        Y DIMENSIONS                         (INPUT)
C              NSLICE      Z DIMENSIONS                         (INPUT)
C
C  PURPOSE: ALTER CONTRAST IN AN IMAGE OR VOLUME USING LOCAL
C           ORIENTATION MEASURE
C                                                                      
C **********************************************************************

	SUBROUTINE ORIENT(LUN1,LUN2,LUN3,NSAM,NROW,NSLICE,IRTFLG)

	INCLUDE 'CMBLOCK.INC'
        INCLUDE 'CMLIMIT.INC'

        REAL, ALLOCATABLE, DIMENSION(:,:) :: BUF,OUTA,OUTM
        CHARACTER(LEN=1) ::                  ANS
        LOGICAL ::                           LOCAL


C       SIGMA IS A NOISE SCALE
        SIGMA   = 2.0
        CALL RDPRM1S(SIGMA,NOT_USED,'SIGMA',IRTFLG)
        IF (IRTFLG .NE. 0) RETURN

        CALL  RDPRMC(ANS,NLET,.TRUE.,'LOCAL OR RADIAL (L/R)',
     &               CHAR(0),IRTFLG)
        IF (IRTFLG .NE. 0) RETURN

        LOCAL = (ANS .NE. 'R')

        ALLOCATE(BUF(NSAM+2,NROW+2),  OUTA(NSAM+2,NROW+2),
     &           OUTM(NSAM+2,NROW+2),STAT=IRTFLG)
        IF (IRTFLG .NE. 0) THEN 
           CALL ERRT(46,'ORIENT, BUF...',IER)
           RETURN
        ENDIF

        DO ISLICE = 1,NSLICE
C          LOAD THIS SLICE INTO CENTRAL PORTION OF BUF 
           J = 2
           DO IREC=(ISLICE-1)*NROW+1,ISLICE*NROW
              CALL REDLIN(LUN1,BUF(2,J),NSAM,IREC)
              J = J + 1
           ENDDO

C          ASSIGN PERIODIC BOUNDARIES
           CALL DUMMIES(BUF, NSAM, NROW)

           IF (LOCAL) THEN
C             FIND LOCAL  ORIENTATION WITHIN IMAGE
              CALL ORIENTED(NSAM,NROW,BUF,SIGMA,OUTA,OUTM,IRTFLG)
           ELSE
C             FIND RADIAL ORIENTATION WITHIN IMAGE
              CALL VECRAD(NSAM,NROW,BUF,SIGMA,OUTA,OUTM,IRTFLG)
           ENDIF
           IF (IRTFLG .NE. 0) GOTO 9999

           J = 2
           DO IREC=(ISLICE-1)*NROW+1,ISLICE*NROW
              CALL WRTLIN(LUN2,OUTA(2,J),NSAM,IREC)
              CALL WRTLIN(LUN3,OUTM(2,J),NSAM,IREC)
              J = J + 1
           ENDDO
        ENDDO
  
9999    IF (ALLOCATED(BUF))  DEALLOCATE(BUF)
        IF (ALLOCATED(OUTA)) DEALLOCATE(OUTA)
        IF (ALLOCATED(OUTM)) DEALLOCATE(OUTM)

        RETURN
        END



C   ---------------------------- ORIENTED ----------------------
C
C
C   PURPOSE:  CALCULATES  ORIENTATION.
C             OR  ORIENTATION RELATIVE TO RADIAL RAY.
C
C   PARAMETERS:
C      NX,NY    IMAGE DIMENSION IN Y & Y 
C      VBUF     IN: REGULARIZED IMAGE, UNCHANGED
C      OUTA     OUT: 2 * ORIENTATION ANGLE
C      OUTM     OUT: ORIENTATION CERTAINTY 
C
C   VARIABLES:
C      DXX      TENSOR ELEMENT
C      DXY      TENSOR ELEMENT 
C      DYY      TENSOR ELEMENT 
C      GRAD    |GRAD(V)|

       SUBROUTINE ORIENTED(NX,NY, VBUF, SIGMA, OUTA,OUTM, IRTFLG)

       DOUBLE PRECISION, DIMENSION(2) ::               VO,VR
       REAL, DIMENSION(NX+2,NY+2) ::                   VBUF,OUTA,OUTM
       DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE :: DXX,DYY,DXY,GRAD
       DOUBLE PRECISION ::                             TOP,BOT,EIG2,EPS
       DOUBLE PRECISION ::                             PI
       DOUBLE PRECISION ::                             DIS1,DIS2
       DOUBLE PRECISION ::                             COSANG,DIS12

       REAL, PARAMETER  :: QUADPI = 3.14159265358979323846 
       REAL, PARAMETER  :: RAD_TO_DGR = (180.0/QUADPI)

       DATA PI/3.1415926535/

       ALLOCATE(DXX(NX+2,NY+2),DXY(NX+2,NY+2),DYY(NX+2,NY+2),
     &           GRAD(NX+2,NY+2), STAT=IRTFLG)
       IF (IRTFLG .NE. 0) THEN 
           CALL ERRT(46,'ORIENTED, DXX...',IER)
           RETURN
       ENDIF

       CALL GET_TENSOR(VBUF, NX, NY, DXX, DXY, DYY, GRAD)

       IF (SIGMA .GT. 0.0) THEN
          CALL GAUSS_CONVD(SIGMA,NX,NY, 1.0,1.0, 1.0,DXX)
          CALL GAUSS_CONVD(SIGMA,NX,NY, 1.0,1.0, 1.0,DXY)
          CALL GAUSS_CONVD(SIGMA,NX,NY, 1.0,1.0, 1.0,DYY)
       ENDIF

C      See JAHNE (Practical Handbook on Image Processing for 
C      Scientific Applications) (1197) pg 431

       EPS   = EPSILON(FLTER)

       DO J=2,NY+1

          DO I=2,NX+1
             TOP   = DXY(I,J)

             EIG2 = 0.5 * (DXX(I,J) + DYY(I,J) - 
     &              SQRT( (DXX(I,J) - DYY(I,J)) **2 + 
     &                     4 * (DXY(I,J)**2)) )

             BOT = EIG2 - DYY(I,J)

             IF (ABS(BOT) .GT. EPS) THEN

#if defined (SP_GFORTRAN)
                OUTA(I,J) = ATAN( TOP / BOT ) * RAD_TO_DGR 
#else
                OUTA(I,J) = ATAND( TOP / BOT ) 
#endif

             ELSE
                OUTA(I,J) = DSIGN(90.0D0, BOT)
             ENDIF

             OUTM(I,J) = GRAD(I,J) 

#ifdef NEVER
             IF (J .le. (NY/2) .and. i .ge. (nx/2)) THEN
             write(6,90) i,j,  top, bot, outa(i,j)
90           format( ' d(',i3,',',i3,'): ',4(f7.2,2x,))
             endif
#endif

          ENDDO
       ENDDO

       IRTFLG = 0

       IF (ALLOCATED(DXX))  DEALLOCATE(DXX)
       IF (ALLOCATED(DXY))  DEALLOCATE(DXY)
       IF (ALLOCATED(DYY))  DEALLOCATE(DYY)
       IF (ALLOCATED(GRAD)) DEALLOCATE(GRAD)
       END

c                IF (J .le. (NY/2) .and. i .ge. (nx/2)) THEN
c                write(6,90) i,j, dxx(i,j), dxy(i,j), dyy(i,j), outa(i,j)
c90              format( ' d(',i3,',',i3,'): ',4(f7.2,2x,))
c                endif
c            EIG1 = 0.5 * (DXX(I,J) + DYY(I,J) + 
c     &             SQRT( (DXX(I,J) - DYY(I,J))**2 + 4 * (DXY(I,J)**2) )
C            TOP = EIG1 - DXX(I,J)
c            BOT = DYY(I,J) - DXX(I,J)


C   ---------------------------- GET_TENSOR ----------------------
C
C
C   PURPOSE:  CALCULATES  TENSOR.
C
C   PARAMETERS:
C      VBUF     IN: REGULARIZED IMAGE, UNCHANGED
C      NX,NY    IMAGE DIMENSION IN Y & Y 
C      DXX      OUT:  TENSOR ELEMENT
C      DXY      OUT:  TENSOR ELEMENT 
C      DYY      OUT:  TENSOR ELEMENT 
C
C   VARIABLES:
C      DV_DX, DV_DY        DERIVATIVES OF VBUF
C      GRAD                |GRAD(V)|


       SUBROUTINE GET_TENSOR(VBUF, NX,NY, DXX,DXY,DYY,GRAD)

       REAL, DIMENSION(NX+2,NY+2) ::             VBUF
       DOUBLE PRECISION, DIMENSION(NX+2,NY+2) :: DXX,DYY,DXY,GRAD
       DOUBLE PRECISION ::                       DV_DX,DV_DY,EPS

       EPS   = EPSILON(flter)

       DO J=2, NY+1
          DO I=2, NX+1

             DV_DX     = (VBUF(I+1,J) - VBUF(I-1,J)) / 2.0
             DV_DY     = (VBUF(I,J+1) - VBUF(I,J-1)) / 2.0
             IF (ABS(DV_DX) .LT. EPS) DV_DX = 0.0
             IF (ABS(DV_Dy) .LT. EPS) DV_Dy = 0.0

             DXX(I,J)  = DV_DX ** 2
             DXY(I,J)  = DV_DX * DV_DY 
             DYY(I,J)  = DV_DY ** 2

C            CALCULATE GRAD MAGNITUDE
             GRAD(I,J) = SQRT(DV_DX **2 + DV_DY **2)

        ENDDO
      ENDDO



      RETURN
      END





C   -------------------------- GAUSS_CONVD--------------------------
C
C   PURPOSE:
C      GAUSSIAN COONVOLUTION. 
C
C   PARAMETERS:
C      SIGMA              STANDARD DEVIATION OF GAUSSIAN 
C      NX                 IMAGE DIMENSION IN X DIRECTION  
C      NY                 IMAGE DIMENSION IN Y DIRECTION  
C      HX                 PIXEL SIZE IN X DIRECTION 
C      HY                 PIXEL SIZE IN Y DIRECTION 
C      PRECISION          CUTOFF AT PRECISION * SIGMA 
C      FBUF               INPUT: ORIGINAL IMAGE   OUTPUT: SMOOTHED 
C   VARIABLES
C      SUM                FOR SUMMING UP
C      CONV               CONVOLUTION VECTOR 
C      HELP               ROW OR COLUMN WITH DUMMY BOUNDARIES


      SUBROUTINE GAUSS_CONVD(SIGMA,NX,NY,HX,HY,PRECISION,FBUF)

      INTEGER  ::                                    P
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:) :: CONV, HELP
      DOUBLE PRECISION, DIMENSION(NX+2,NY+2) ::      FBUF
      DOUBLE PRECISION  ::                           SUM
      
C     DIFFUSION IN X DIRECTION ------------

C     CALCULATE LENGTH OF CONVOLUTION VECTOR
      LENGTH = (PRECISION * SIGMA / HX) + 1
      IF (LENGTH .GT. NX) THEN
         CALL ERRT(101,'GAUSS_CONV: SIGMA TOO LARGE',NE) 
         RETURN
      ENDIF

C     ALLOCATE STORAGE FOR CONVOLUTION VECTOR & ROW
      ALLOCATE(CONV(LENGTH+1), HELP(NX+LENGTH+LENGTH), STAT=IRTFLG)
      IF (IRTFLG .NE. 0)  THEN
         CALL  ERRT(101,'UNABLE TO ALLOCATE CONV & ROW',NE)
         RETURN
      ENDIF

C     CALCULATE ENTRIES OF CONVOLUTION VECTOR
      SUM = 0.0
      DO I=1, LENGTH+1
         CONV(I) = 1 / (SIGMA * SQRT(2.0 * 3.1415926)) *
     &       EXP (- ((I-1) * (I-1) * HX * HX) / (2.0 * SIGMA * SIGMA))
         SUM = SUM + 2.0 * CONV(I)
      ENDDO

C     DIVISION OVER ALL OF CONV VECTOR
      CONV = CONV / SUM

      DO  J=2, NY+1

C        COPY IN ROW VECTOR
         DO I=2,NX+1
            HELP(I+LENGTH-1) = FBUF(I,J)
         ENDDO

C        PERIODIC B.C.
         DO P=0, LENGTH-1
C           LEFT BOUNDARY
            HELP(LENGTH-P)      = HELP(NX+LENGTH-P)
C           RIGHT BOUNDARY
            HELP(NX+LENGTH+1+P) = HELP(LENGTH+P+1)
         ENDDO

C        CONVOLUTION STEP
         DO I=LENGTH+1, NX+LENGTH

C           CALCULATE CONVOLUTION
            SUM = 0.0

            DO P=1, LENGTH+1
               SUM = SUM + CONV(P) * (HELP(I+P) + HELP(I-P))
            ENDDO

C           WRITE BACK
            FBUF(I-LENGTH+1,J) = SUM
         ENDDO
       ENDDO

       IF (ALLOCATED(HELP)) DEALLOCATE(HELP)
       IF (ALLOCATED(CONV)) DEALLOCATE(CONV)


C      --------------------- DIFFUSION IN Y DIRECTION ----------------

C     CALCULATE LENGTH OF CONVOLUTION VECTOR
      LENGTH = (PRECISION * SIGMA / HY) + 1
      IF (LENGTH .GT. NY) THEN
         CALL ERRT(101,'GAUSS_CONV: SIGMA TOO LARGE',NE) 
         RETURN
      ENDIF

C     ALLOCATE STORAGE FOR CONVOLUTION VECTOR & ROW
      ALLOCATE(CONV(LENGTH+1),HELP(NY+LENGTH+LENGTH), STAT=IRTFLG)
      IF (IRTFLG .NE. 0)  THEN
         CALL  ERRT(101,'UNABLE TO ALLOCATE CONV & ROW',NE)
         RETURN
      ENDIF

C     CALCULATE ENTRIES OF CONVOLUTION VECTOR
      SUM = 0.0
      DO I=1, LENGTH+1
         CONV(I) = 1 / (SIGMA * SQRT(2.0 * 3.1415926)) *
     &           EXP (- ((I-1) * (I-1) * HY * HY) / 
     &           (2.0 * SIGMA * SIGMA))
         SUM = SUM + 2.0 * CONV(I)
      ENDDO

      CONV = CONV / SUM

      DO  I=2, NX+1

C        COPY IN COL VECTOR
         DO J=1+1,NY+1
            HELP(J+LENGTH-1) = FBUF(I,J)
         ENDDO

C        ASSIGN BOUNDARY CONDITIONS, PERIODIC B.C.
         DO P=0, LENGTH-1
C           LEFT BOUNDARY
            HELP(LENGTH-P)      = HELP(NY+LENGTH-P)
C           RIGHT BOUNDARY
            HELP(NY+LENGTH+1+P) = HELP(LENGTH+P+1)
         ENDDO

C        CONVOLUTION STEP
         DO J=LENGTH+1, NY+LENGTH

C           CALCULATE CONVOLUTION
            SUM = 0.0

            DO P=1, LENGTH+1
               SUM = SUM + CONV(P) * (HELP(J+P) + HELP(J-P))
            ENDDO

C           WRITE BACK
            FBUF(I,J-LENGTH+1) = SUM
         ENDDO
      ENDDO

      IF (ALLOCATED(HELP)) DEALLOCATE(HELP)
      IF (ALLOCATED(CONV)) DEALLOCATE(CONV)
 
      RETURN
      END


C   ---------------------------- VECRAD ----------------------
C
C
C   PURPOSE:  CALCULATES  GRADIANT VECTOR RELATIVE TO RADIAL RAY.
C
C   PARAMETERS:
C      NX,NY    IMAGE DIMENSION IN Y & Y 
C      VBUF     IN: REGULARIZED IMAGE, UNCHANGED
C      OUTA     OUT: GRADIANT ANGLE
C      OUTM     OUT: GRADIANT MAGNITUDE 
C   VARIABLES:
C      DXX      GRADIANT x
C      DYY      GRADIANT y 
C      GRAD    |GRAD(V)|

       SUBROUTINE VECRAD(NX,NY, VBUF, SIGMA, OUTA,OUTM, IRTFLG)

       DOUBLE PRECISION, DIMENSION(2) ::               VR
       REAL, DIMENSION(NX+2,NY+2) ::                   VBUF,OUTA,OUTM
       DOUBLE PRECISION, DIMENSION(:,:),ALLOCATABLE :: DXX,DYY,GRAD
       DOUBLE PRECISION ::                             XC,YC
       DOUBLE PRECISION ::                             DIS1,DIS2
       DOUBLE PRECISION ::                             COSANG,DIS12

       REAL, PARAMETER  :: QUADPI = 3.14159265358979323846 
       REAL, PARAMETER  :: RAD_TO_DGR = (180.0/QUADPI)


       ALLOCATE(DXX(NX+2,NY+2),DYY(NX+2,NY+2),
     &           GRAD(NX+2,NY+2), STAT=IRTFLG)
       IF (IRTFLG .NE. 0) THEN 
           CALL ERRT(46,'ORIENTED, DXX...',IER)
           RETURN
       ENDIF

       CALL GET_GRAD(VBUF, NX, NY, DXX, DYY, GRAD)

       IF (SIGMA .GT. 0.0) THEN
          CALL GAUSS_CONVD(SIGMA,NX,NY, 1.0,1.0, 1.0,DXX)
          CALL GAUSS_CONVD(SIGMA,NX,NY, 1.0,1.0, 1.0,DYY)
       ENDIF

       EPS   = EPSILON(FLTER)

C      CENTER OF IMAGE 
       XC  = NX / 2 + 2
       YC  = NY / 2 + 2

       DO J=2,NY+1
          VR(2) = J - YC

          DO I=2,NX+1
C            VERSUS RADIAL
             VR(1) = I - XC

C            FIND ANGLE BETWEEN LINES  
             DIS1    = DXX(I,J)**2 + DYY(I,J)**2
             DIS2    = VR(1)**2    + VR(2)**2
             DIS12   = DIS1        * DIS2

             IF (ABS(DIS12)  < EPS .OR. SQRT(DIS12) < EPS) THEN
C               REJECT DUPLICATED POINTS OR GET DIVISION BY ZERO!
                OUTA(I,J) = 0.0
             ELSE 
                UP        = DXX(I,J) * VR(1) + DYY(I,J) * VR(2)
                COSANG    = UP / SQRT(DIS12)
                COSANG    = MAX(-1.0,MIN(REAL(COSANG),1.0))

#if defined (SP_GFORTRAN)
                OUTA(I,J) = ACOS(COSANG) * RAD_TO_DGR
#else
                OUTA(I,J) = ACOSD(COSANG)
#endif

             ENDIF

             OUTM(I,J) = GRAD(I,J) 

#ifdef NEVER
                  IF ((J .eq. 42 .and. i .eq. 62) .or.
     &                (J .eq. 62 .and. i .eq. 62)) THEN
                  write(6,*) ' '
                  write(6,95)I,J,  DXX(I,J),DYY(I,J)
95                FORMAT(' DXX,DYY ----------(',i2,',',i2,'): ',
     &                     7(g13.5,1x,))

                  write(6,94)I,J,  VR(1),VR(2),G2
94                FORMAT(' VR,VR2,G2 --------(',i2,',',i2,'): ',
     &                     7(g13.5,1x,))

                  write(6,97)I,J,  UP,DIS12,SQRT(DIS12)
97                format(' UP,D12,SQRTD12----(',i2,',',i2,'): ',
     &                      7(g13.5,1x,))

                  write(6,99)I,J,COSANG,OUTA(I,J),OUTM(i,J)
99                format(' COSANG,OUTA-------(',i2,',',i2,'): ',
     &                     7(g13.5,1x,))

                   write(6,*) ' '
                   endif
                   IF (J .le. (NY/2) .and. i .ge. (nx/2)) THEN
                   write(6,90) i,j,  top, bot, outa(i,j)
90                 format( ' d(',i3,',',i3,'): ',4(f7.2,2x,))
                   endif
#endif

          ENDDO
       ENDDO

       IRTFLG = 0

       IF (ALLOCATED(DXX))  DEALLOCATE(DXX)
       IF (ALLOCATED(DYY))  DEALLOCATE(DYY)
       IF (ALLOCATED(GRAD)) DEALLOCATE(GRAD)
       END
      

 
C   ---------------------------- GET_GRAD ----------------------
C
C
C   PURPOSE:  CALCULATES  GRADIENT.
C
C   PARAMETERS:
C      VBUF     IN: REGULARIZED IMAGE, UNCHANGED
C      NX,NY    IMAGE DIMENSION IN Y & Y 
C      DXX      OUT:  GRADIENT X
C      DYY      OUT:  GRADIENT Y 
C
C   VARIABLES:
C      DV_DX, DV_DY        DERIVATIVES OF VBUF
C      GRAD                |GRAD(V)|


       SUBROUTINE GET_GRAD(VBUF, NX,NY, DXX,DYY,GRAD)

       REAL, DIMENSION(NX+2,NY+2) ::             VBUF
       DOUBLE PRECISION, DIMENSION(NX+2,NY+2) :: DXX,DYY,GRAD
       DOUBLE PRECISION ::                       DV_DX,DV_DY,EPS

       EPS   = EPSILON(flter)
       CON   = 1.0 / 32.0

       DO J=2, NY+1
          DO I=2, NX+1

             DV_DX = CON * (10 * VBUF(I+1,J)   - 10 * VBUF(I-1,J)   +
     &                       3 * VBUF(I+1,J+1) -  3 * VBUF(I-1,J-1) + 
     &                       3 * VBUF(I+1,J-1) -  3 * VBUF(I-1,J+1)) 

             DV_DY = CON * (10 * VBUF(I,J+1)   - 10 * VBUF(I,J-1)   +
     &                       3 * VBUF(I+1,J+1) -  3 * VBUF(I-1,J-1) + 
     &                       3 * VBUF(I-1,J+1) -  3 * VBUF(I+1,J-1)) 

C            CALCULATE GRAD MAGNITUDE
             GRAD(I,J) = SQRT(DV_DX **2 + DV_DY **2)
             DXX(I,J) = DV_DX
             DYY(I,J) = DV_DY 


#ifdef NEVER
                  IF ((J .eq. 42 .and. i .eq. 62) .or.
     &                (J .eq. 62 .and. i .eq. 62)) THEN
                  write(6,*) ' '
                  write(6,95)I,J,  VBUF(I,J),VBUF(I+1,J),VBUF(I-1,J)
95                FORMAT(' VBUF ----------(',i2,',',i2,'): ',
     &                     7(g13.5,1x,))

                  write(6,94)I,J, GRAD(I,J)
94                FORMAT(' GRAD ----------(',i2,',',i2,'): ',
     &                     7(g13.5,1x,))


                  write(6,99)I,J,DXX(I,J),DYY(I,J)
99                format(' DXX,DYY--------(',i2,',',i2,'): ',
     &                     7(g13.5,1x,))

                   write(6,*) ' '
                   endif
#endif



        ENDDO
      ENDDO

      RETURN
      END

