
C ++********************************************************************
C                                                                      *
C                                                                      *
C                                                                      *
C **********************************************************************
C=*                                                                    *
C=* This file is part of:   SPIDER - Modular Image Processing System.  *
C=* SPIDER System Authors:  Joachim Frank & ArDean Leith               *
C=* Copyright 1985-2010  Health Research Inc.,                         *
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
C                                                                      *
C                                                                      *
C                                                                      *
C  PURPOSE:                                                            *
C     COMPUTES THE SCALE FACTOR OF VPT WITH RESPECT TO RPT, USING ONLY
C     POINTS THEY HAVE IN COMMON. THIS THEN MUST BE APPLIED TO VPT
C     TO MAKE IT FIT TO RPT
C
C     USES ROOT OF RATIO BETWEEN SUM OF SQUARES OF COORDS OF RPT/VPT.
C
C INPUT:
C     RPT(3,LS)= COORDS OF POINTS IN REFERENCE VIEW
C     VPT(3,LS)= COORDS OF POINTS IN VIEW TO BE ADJUSTED
C     IVIEW= INDEX OF VIEW TO BE REFINED
C COMMON INPUT:
C     PTACTIVE(LS,LV)= BOOLEAN ARRAY REFERENCING POINTS TO BE USED
C          (IE. CAN BE FOUND IN VPT VIEW) .TRUE. IF USED
C     NUMPT(LV)= MAXIMUM INDEX OF POINTS USED IN VPT
C OUTPUT:
C     SCALEI= SCALE FACTOR OF VPT VIEW WITH RESPECT TO RPT VIEW
C                                                                      *
C  PARAMETERS:                                                         *
C                                                                      *
C23456789012345678901234567890123456789012345678901234567890123456789012
C***********************************************************************

      SUBROUTINE MRSCALE(RPT, VPT, IVIEW, SCALEI,PTACTIVE,NUMPTS)

      PARAMETER (LV=300)
      PARAMETER (LS=256)

      LOGICAL           PTACTIVE(LS,LV)
      INTEGER           NUMPTS(LV)

      DIMENSION         RPT(2,LS), VPT(2,LS), SCALEI(LV)
      DOUBLE PRECISION  RSUM,VSUM

      RSUM = 0.0
      VSUM = 0.0

C     SUMS UP THE SQUARES OF THE COORDS
      DO  M=1,NUMPTS(IVIEW)
        IF (PTACTIVE(M,IVIEW)) THEN
          RSUM = RSUM + RPT(1,M) * DBLE(RPT(1,M))
     &                + RPT(2,M) * DBLE(RPT(2,M))
          VSUM = VSUM + VPT(1,M) * DBLE(VPT(1,M))
     &                + VPT(2,M) * DBLE(VPT(2,M))
	ENDIF
      ENDDO

      SCALEI(IVIEW)= DSQRT(RSUM / VSUM)

      END
