
C++*********************************************************************C
C  ANISOE.F                   NEW MAR 2002 ARDEAN LEITH
C
C **********************************************************************
C      PORTED FROM C CODE by A. Leith

C      Copyright (C) 1997 by Robert R. Estes Jr.

C      Permission to use, copy, modify, and distribute this software and its
C      DOcumentation for any purpose and without fee is hereby granted, provided
C      that the above copyright notice appear in all copies and that both that
C      copyright notice and this permission notice appear in supporting
C      documentation.  This software is provided "as is" without express or
C      implied warranty.

C      This program implements Adel's CPF algorithm. 

C      The Sobel operator is used to compute first and second order
C      derivatives. 
C      Compute the diffusion coefficient image. 
C      The value computed at each pixel is: 

C       1 / (8*W*\sqrt{1+(T2H(W-1))^2} 
C       where:
      
C        T2H = (GL-2FM+EN)/W^2

C        E = 1+BX^2, F = BX BY, G = 1+BY^2, 
C        L = FXX/W,  M = FXY/W, N = FYY/W,
C        W = \ SQRT{EG-F^2}
C **********************************************************************

      SUBROUTINE ANISOE(BUF,NSAM,NROW,ITER,IRTFLG)

      REAL, DIMENSION(NSAM,NROW),INTENT(INOUT) :: BUF

      DOUBLE PRECISION, DIMENSION(NSAM,NROW) :: DBUF
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: OUT,BX,BY,CD
      DOUBLE PRECISION :: CSUM,FXX,FXY,FYY,E,F,G,WSQ,W,FL,FN,FM

      ALLOCATE(OUT(NSAM,NROW),BX(NSAM,NROW),
     &         BY(NSAM,NROW),CD(NSAM,NROW), STAT=IRTFLG)
      IF (IRTFLG .NE. 0) THEN 
         CALL ERRT(46,'ANISO, OUT...',IER)
         RETURN
      ENDIF

      DBUF = BUF
      OUT  = 0.0
      BX   = 0.0
      BY   = 0.0
      CD   = 0.0
      EPS = EPSILON(EPS)

C     bx =  -1  0  1    by =  -1 -2 -1   fxx = fxy = bx    fyy = by
C           -2  0  2           0  0  0   (on bx & bxby)      (on by)
C           -1  0  1           1  2  1

     

      DO I = 1, ITER
         DO IY = 2,NROW-1
            DO IX = 2,NSAM-1
	      BX(IX,IY) = (DBUF(IX+1,IY-1) + 2*DBUF(IX+1,IY) + 
     &                     DBUF(IX+1,IY+1) -   DBUF(IX-1,IY-1) - 
     &                     2*DBUF(IX-1,IY) -   DBUF(IX-1,IY+1) )/4

	      BY(IX,IY) = (DBUF(IX-1,IY+1) + 2*DBUF(IX,IY+1) + 
     &                     DBUF(IX+1,IY+1) -   DBUF(IX-1,IY-1) - 
     &                   2*DBUF(IX,IY-1)   -   DBUF(IX+1,IY-1) )/4 
            ENDDO
         ENDDO

         DO IY = 3, NROW-2
            DO IX = 3, NSAM-2

	       FXX = (BX(IX+1,IY-1) + 2*BX(IX+1,IY) + BX(IX+1,IY+1) -
     &                BX(IX-1,IY-1) - 2*BX(IX-1,IY) - BX(IX-1,IY+1) )/4

	       FXY = (BY(IX+1,IY-1) + 2*BY(IX+1,IY) + BY(IX+1,IY+1) -
     &                BY(IX-1,IY-1) - 2*BY(IX-1,IY) - BY(IX-1,IY+1) )/4

	       FYY = (BY(IX-1,IY+1) + 2*BY(IX,IY+1) + BY(IX+1,IY+1) -
     &                BY(IX-1,IY-1) - 2*BY(IX,IY-1) - BY(IX+1,IY-1) )/4
	
	       E   = 1+BX(IX,IY) * BX(IX,IY) 
	       F   =   BX(IX,IY) * BY(IX,IY) 
	       G   = 1+BY(IX,IY) * BY(IX,IY) 
	
	       WSQ = (E*G-F*F)
               IF (WSQ .LE. EPS) THEN
C                 ADDED TO TRAP / BY ZERO, I DO NOT KNOW WHAT IT
C                 SHOULD BE!  al may 02, changed Oct 02
                  CD(IX,IY) = 1.0
               ELSE
	          W   = SQRT(WSQ)
	          FL  = FXX / W
	          FM  = FXY / W
	          FN  = FYY / W
 	          TMP = (G*FL-2*F*FM+E*FN) * (W-1) / WSQ

	          CD(IX,IY) = 1.0 / (8*W * SQRT(1+TMP**2))
               ENDIF
            ENDDO
         ENDDO

C        COMPUTE NEXT ITERATION.  THE FILTER IS OBTAINED BY TAKING THE
C        EIGHT NEIGHBORS OF EACH PIXEL WEIGHTED BY THE CORRESPONDING
C        COEFFICIENTS ABOVE, AND THEN ADDING 1-THEIR SUM TIMES THE CENTER
C        PIXEL. 

         DO IY = 3, NROW-2
            DO IX = 3, NSAM-2
               OUT(IX,IY) = 0.0
               CSUM       = 0.0
	       DO IY1 = IY-1,IY+1
	          DO IX1 = IX-1,IX+1
	             IF (IX .NE. IX1 .OR. IY .NE. IY1) THEN 
	                OUT(IX,IY) = OUT(IX,IY) +
     &                               CD(IX1,IY1) * DBUF(IX1,IY1) 
	                CSUM = CSUM + CD(IX1,IY1) 
                     ENDIF
                  ENDDO
	       ENDDO
	       OUT(IX,IY) = OUT(IX,IY) + (1-CSUM) * DBUF(IX,IY) 
            ENDDO
         ENDDO
       
C        GET READY FOR THE NEXT ITERATION. COPY THE COMPUTED VALUES INTO
C        THE ORIGINAL IMAGE, SO THAT THE ORIGINAL VALUES ARE USED AT THE
C        BOUNDARIES TO REDUCE BOUNDARY EFFECTS.

         DO IY = 3,NROW-2
            DO IX = 3,NSAM-2
               DBUF(IX,IY) = OUT(IX,IY) 
            ENDDO
          ENDDO
       ENDDO

       BUF = DBUF

       IF (ALLOCATED(OUT)) DEALLOCATE(OUT)
       IF (ALLOCATED(BX))  DEALLOCATE(BX)
       IF (ALLOCATED(BY))  DEALLOCATE(BY)
       IF (ALLOCATED(CD))  DEALLOCATE(CD)

       END






C **********************************************************************
C      PORTED FROM C CODE by A. Leith
C
C      Copyright (C) 1997 by Robert R. Estes Jr.
C
C      Permission to use, copy, modify, and distribute this software and its
C      DOcumentation for any purpose and without fee is hereby granted, provided
C      that the above copyright notice appear in all copies and that both that
C      copyright notice and this permission notice appear in supporting
C      documentation.  This software is provided "as is" without express or
C      implied warranty.
C
C      This program implements Adel's MCD algorithm. 
C
C      The Sobel operator is used to compute gradient.
C       
C      Compute the diffusion coefficient image. 
C      The value computed at each pixel is: 
C
C       1 / (8*W*\sqrt{1+(G**2} 
C       where:
C
C        G  - gradient magnitude
C        W =  weighting factor
C
C **********************************************************************

      SUBROUTINE ANISOE_M(W,BUF,NSAM,NROW,ITER,IRTFLG)

      REAL, DIMENSION(NSAM,NROW),INTENT(INOUT) :: BUF

      DOUBLE PRECISION, DIMENSION(NSAM,NROW) :: DBUF
      DOUBLE PRECISION, ALLOCATABLE, DIMENSION(:,:) :: OUT,CD
      DOUBLE PRECISION :: CSUM,WSQ

      ALLOCATE(OUT(NSAM,NROW),CD(NSAM,NROW), STAT=IRTFLG)
      IF (IRTFLG .NE. 0) THEN 
         CALL ERRT(46,'ANISO, OUT & CD',IER)
         RETURN
      ENDIF

      DBUF = BUF
      OUT  = 0.0
      CD   = 0.0
      WSQ  = W * W

C     bx =  -1  0  1    by =  -1 -2 -1    
C           -2  0  2           0  0  0    
C           -1  0  1           1  2  1

      DO I = 1, ITER
         DO IY = 2,NROW-1
            DO IX = 2,NSAM-1
	      BX        = (DBUF(IX+1,IY-1) + 2*DBUF(IX+1,IY) + 
     &                     DBUF(IX+1,IY+1) -   DBUF(IX-1,IY-1) - 
     &                     2*DBUF(IX-1,IY) -   DBUF(IX-1,IY+1) )/4

	      BY        = (DBUF(IX-1,IY+1) + 2*DBUF(IX,IY+1) + 
     &                     DBUF(IX+1,IY+1) -   DBUF(IX-1,IY-1) - 
     &                   2*DBUF(IX,IY-1)   -   DBUF(IX+1,IY-1) )/4

              CD(IX,IY) = WSQ / (8 * SQRT(1 + BX*BX + BY*BY))
 
            ENDDO
         ENDDO

C        COMPUTE NEXT ITERATION.  THE FILTER IS OBTAINED BY TAKING THE
C        EIGHT NEIGHBORS OF EACH PIXEL WEIGHTED BY THE CORRESPONDING
C        COEFFICIENTS ABOVE, AND THEN ADDING 1-THEIR SUM TIMES THE CENTER
C        PIXEL. 

         DO IY = 2, NROW-1
            DO IX = 2, NSAM-1
               OUT(IX,IY) = 0.0
               CSUM       = 0.0

	       DO IY1 = IY-1,IY+1
	          DO IX1 = IX-1,IX+1
	             IF (IX .NE. IX1 .OR. IY .NE. IY1) THEN 
	                OUT(IX,IY) = OUT(IX,IY) +
     &                               CD(IX1,IY1) * DBUF(IX1,IY1) 
	                CSUM = CSUM + CD(IX1,IY1) 
                     ENDIF
                  ENDDO
	       ENDDO
	       OUT(IX,IY) = OUT(IX,IY) + (1-CSUM) * DBUF(IX,IY) 
            ENDDO
         ENDDO
       
C        GET READY FOR THE NEXT ITERATION. COPY THE COMPUTED VALUES INTO
C        THE ORIGINAL IMAGE, SO THAT THE ORIGINAL VALUES ARE USED AT THE
C        BOUNDARIES TO REDUCE BOUNDARY EFFECTS.

         DO IY = 2,NROW-1
            DO IX = 2,NSAM-1
               DBUF(IX,IY) = OUT(IX,IY) 
            ENDDO
          ENDDO
       ENDDO

       BUF = DBUF

       IF (ALLOCATED(OUT)) DEALLOCATE(OUT)
       IF (ALLOCATED(CD))  DEALLOCATE(CD)

       END
