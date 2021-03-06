C++*********************************************************************
C
C  MAKE_CLOSE_LIST                                 FEB 11 ARDEAN LEITH
C
C **********************************************************************
C=* This file is part of:                                              * 
C=* SPIDER - Modular Image Processing System.                          *
C=* Authors: J. Frank & A. Leith                                       *
C=* Copyright 1985-2011  Health Research Inc.                          *
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
C=* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  *
C=* General Public License for more details.                           *
C=*                                                                    *
C=* You should have received a copy of the GNU General Public License  *
C=* along with this program. If not, see <http://www.gnu.org/licenses> *       
C=*                                                                    *
C **********************************************************************
C
C
C PARAMETERS:
C       NUMREF              NO. OF IMAGES                      (INPUT)
C       LIMITRANGE          LIMIT THE ANG. DISTANCE            (INPUT)
C       REFDIR              REF. IMAGE ANGLES                  (INPUT)
C       EXPDIR              EXP. IMAGE ANGLES                  (INPUT)
C       RANGECOS            ANGULAR DISTANCE                   (INPUT)
C       CKMIRROR            CHECK MIRRORD ANGLES               (INPUT)
C       LCGPOINTER          LIST OF CLOSE IMAGES               (RET.)
C       NCLOSE              # OF CLOSE IMAGES                  (RET.)
C       IRTFLG              ERROR FLAG                         (RET.)

C--*********************************************************************
  
      SUBROUTINE MAKE_CLOSE_LIST(NUMREF,LIMITRANGE,
     &                           REFDIR,EXPDIR,
     &                           RANGECOS, CKMIRROR, 
     &                           LCGPOINTER, NCLOSE, IRTFLG)

      IMPLICIT NONE

      INTEGER, INTENT(IN)  :: NUMREF 
      LOGICAL, INTENT(IN)  :: LIMITRANGE
      REAL,    INTENT(IN)  :: REFDIR(3,NUMREF), EXPDIR(3)
      REAL,    INTENT(IN)  :: RANGECOS
      LOGICAL, INTENT(IN)  :: CKMIRROR
      INTEGER, POINTER     :: LCGPOINTER(:)
      INTEGER, INTENT(OUT) :: NCLOSE, IRTFLG

      REAL                 :: DT,DTABS
      INTEGER              :: IREF


      IF (.NOT. LIMITRANGE) THEN
         IF (.NOT. ASSOCIATED(LCGPOINTER)) THEN
C           DUMMY ALLOCATE TO AVOID BUS ERROR ON SOME SYSTEMS
            ALLOCATE(LCGPOINTER(1),STAT=IRTFLG)
         ENDIF
         NCLOSE = NUMREF
#ifndef __INTEL_COMPILER
         LCGPOINTER(1) = -999  ! BUG FLAG
#endif
         RETURN
      ENDIF

C     RESTRICTED RANGE SEARCH ------------------------------------
      IF (.NOT. ASSOCIATED(LCGPOINTER)) THEN
         ALLOCATE(LCGPOINTER(NUMREF),STAT=IRTFLG)
         IF (IRTFLG .NE. 0) THEN
            CALL ERRT(46,'LCG',NUMREF)
            RETURN
         ENDIF
      ENDIF

C     MAKE LIST OF NEARBY REFERENCE IMAGES
      NCLOSE = 0

      DO IREF=1,NUMREF 
C        DT NEAR 1.0 = NOT-MIRRORED, DT NEAR -1.0 = MIRRORED
         DT    = (EXPDIR(1) * REFDIR(1,IREF) + 
     &            EXPDIR(2) * REFDIR(2,IREF) +
     &            EXPDIR(3) * REFDIR(3,IREF))
	 DTABS = ABS(DT)

         IF (DTABS >= RANGECOS)  THEN
C           MIRRORED OR NON-MIRRORED IS WITHIN RANGE

            IF (CKMIRROR .OR. DT > 0) THEN
C              DO NOT DISCARD IF NOT MIRRORED OR WANT MIRRORED
	       NCLOSE             = NCLOSE + 1
	       LCGPOINTER(NCLOSE) = IREF
               IF (DT < 0) LCGPOINTER(NCLOSE) = -IREF
            ENDIF
         ENDIF
      ENDDO
      IRTFLG = 0
      !print *,'makelist, ref:',refdir(:,1)
      !print *,'makelist, exp:',expdir


      END



