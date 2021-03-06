C ****************************************************************************
C  TFLM4.F  
C
C*****************************************************************************
C=* From: SPIDER - MODULAR IMAGE PROCESSING SYSTEM                     *
C=* Copyright (C)2003, 2015, P. A. Penczek                             *
C=* University of Texas - Houston Medical School                       *
C=* Email:  pawel.a.penczek@uth.tmc.edu                                *
C=*                                           *
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
C****************************************************************************
C
C PURPOSE: DETERMINE DEFOCUS AND ASTIGMATISM OF THE 
C		MICROGRAPH FROM 2D POWER SPECTRUM 
C                      
C OUTPUT OF THIS PROGRAM:1. C1,C2 which give evelope function exp(.5*(x/c2)+c1)
C                        2. Signal with residual noise ( PW of ptl - lines)
C			 3. Residual  noise  PW of noise -lines
C 			 4. P_SB 2-3 (assumed true signal)
C			 5. Wien filter 
C	                 7. Envelope exp(.5*(x/c2)+c1) L2 fitting according to P_SB
C			 6. CTF**2*ENV**2*PU  PU is the signal of model protein
C ****************************************************************************
 
      	SUBROUTINE  TFLM4

	INCLUDE 'CMBLOCK.INC'
      	INCLUDE 'F90ALLOC.INC'
	INCLUDE 'CMLIMIT.INC'

	COMMON /CTF1/ PS,XLAMBDA,CS,CONTRAST,DEFOCUS,QUADPI,
     &	     XALF1,XBETA1,ALF1,ALF2,BETA1,BETA2,V_RATIO,ISWI

        CHARACTER(LEN=MAXNAM) :: DOCNAM1

	PARAMETER  (NLIST=7)
      	REAL	DLIST(NLIST)  
	REAL, DIMENSION(:,:), POINTER   :: DOCBUF1
      	REAL, DIMENSION(:), ALLOCATABLE :: PLOT

	DATA LUN1/78/
	DATA LUN2/89/
      	DATA NDOC/87/	

	QUADPI = 3.14159265
	ISWI   = 4

        CALL RDPRM2S(PS,CS,NOT_USED,
     &      'PIXEL SIZE[A] & SPHERICAL ABERRATION CS[MM]',IRTFLG)

        IF (CS < 0.0001) CS = 0.0001
C     	CONVERT CS TO [A]
      	CS = CS*1.0E07

      	CALL RDPRM1S(XLAMBDA,NOT_USED,
     &          'ELECTRON WAVELENGTH - LAMBDA [A]',IRTFLG)

      	CALL RDPRM1S(CONTRAST,NOT_USED,
     &              'AMPLITUDE CONTRAST RATIO [0-1]',IRTFLG)

	CALL RDPRM1S(DEFOCUS,NOT_USED,
     &               'ESTIMATED DEFOCUS',IRTFLG)
	
	MAXX1=0 
	MAXY1=0
	
	CALL GETDOCDAT("MICROGRAPH 1-D POWER SPECTUM DOC FILE", 
     &                 .TRUE.,DOCNAM1,
     &                 LUN1,.TRUE.,MAXX1, MAXY1,DOCBUF1,IRTFLG)
	IF (IRTFLG .NE. 0) RETURN	

	ALLOCATE(PLOT(MAXY1),STAT=IRTFLG)
	IF (IRTFLG .NE. 0) THEN
            CALL ERRT(46,'TFLM',MAXY1)
            RETURN
        ENDIF

        PLOT(:) = DOCBUF1(2,1:MAXY1)

	CALL LM4(PLOT,MAXY1,LM_IERR)

	TMP2=beta2
	TMP1=beta1
	  DO II=1,MAXY1

	       DLIST(1) = II
	       TX=real(II-1)/real(MAXY1)/2./PS
	       CTF=SIN(-(QUADPI*(DEFOCUS*XLAMBDA*TX**2-
     &		(CS*XLAMBDA**3*TX**4/2.0)))
     &       -ATAN(CONTRAST/(1.-CONTRAST)))
	
	       BASE_LINE=TMP2*EXP(ALF2*TX)
	       CTF_NOISE=TMP1*EXP(-(TX*ALF1)**2)*CTF**2
	       DLIST(2)=TX		
	       DLIST(3)=CTF**2
	       DLIST(4)=BASE_LINE
	       DLIST(5)=CTF_NOISE
	       DLIST(6)=BASE_LINE+CTF_NOISE
	       DLIST(7)=PLOT(II)

	    CALL SAVD(NDOC,DLIST,NLIST,IRTFLG)
	  ENDDO
	CALL SAVDC
	CLOSE(NDOC)
	TMP3=real(LM_IERR)
	CALL REG_SET_NSEL(1,5,ALF1,ALF2,beta1,beta2,
     &      TMP3,IRTFLG)		
	DEALLOCATE(DOCBUF1,plot)
        END
CC======================================================================
C Test levenberg-Marqardt optimization algorithm
C			Zhong Huang, March, 3, 2005
	SUBROUTINE LM4(PLOT,N,LM_IERR )
	DIMENSION PLOT(N)
	DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: Y,W,ALF,BETA
	DOUBLE PRECISION, DIMENSION(:,:), ALLOCATABLE :: A,T
	INTEGER,DIMENSION(:,:), ALLOCATABLE :: INC
	EXTERNAL ADA
	COMMON /CTF1/ PS,XLAMBDA,CS,CONTRAST,DEFOCUS,QUADPI,
     &	XALF1,XBETA1,ALF1,ALF2,BETA1,BETA2,V_RATIO,ISWI
	
 	DOUBLE PRECISION TMP1,TM2,TMP3
C  Number of Linear seperatable parameters Beta
	L=2 
C  Number of non-linear parameters Alf
	NL=2
c  observations	
C number of imdependent variables T 
	IV=1
c 	
	IP=2
	
	LPP2=L+IP+2

	NMAX=MAX(N,2*NL+3)
	
	IPRINT=-1
	
	ALLOCATE(A(NMAX, LPP2), BETA(L), ALF(NL), T(NMAX, IV),   
     &     W(N), Y(N),INC(12,8))	

C simple test, we assume the observation is from one simple gaussian fucniton
	
cc define weighting function   	
	
ccWe always discuss functions within [0,.2] only!

	DO II=1,N
            Y(II)=DBLE(PLOT(II))
	ENDDO

	W=1.0/Y	
	
		
	DO II=1,N
	  T(II,1)=DBLE(II-1)/DBLE(N)/2.0/DBLE(PS)
	
	ENDDO

	ALF(1)=19.
	ALF(2)=-21.
		
 	CALL VARPRO (L, NL, N, NMAX, LPP2, IV, T, Y, W, ADA, A,       
     X IPRINT, ALF, BETA, IERR)            
	LM_IERR=IERR 
	ALF1=SNGL(ALF(1))
	ALF2=SNGL(ALF(2))	
	BETA1=SNGL(BETA(1))
 	BETA2=SNGL(BETA(2))
	DEALLOCATE(Y,W,ALF,T,INC,A,BETA)			 
	END
	
	
cccc	
	SUBROUTINE ADA (L1, NL, N, NMAX, LPP2, IV, A, INC, T, ALF,    
     &   ISEL)
	
        DOUBLE PRECISION A(NMAX, LPP2),ALF(NL),T(NMAX, IV),B(NMAX,L1),
     & 	 Y(N),W(N),CTF(N),PU,AA,BB,CC
	INTEGER INC(12,8)

	COMMON /CTF1/ PS,XLAMBDA,CS,CONTRAST,DEFOCUS,QUADPI, 
     &   XALF1,XBETA1,ALF1,ALF2,BETA1,BETA2,V_RATIO,ISWI
       

        IF(ISWI.EQ.4) THEN
    
	DO II=1,N
	  TMPX=SIN(-(QUADPI*(DEFOCUS*XLAMBDA*SNGL(T(II,1))**2-
     &		(CS*XLAMBDA**3*SNGL(T(II,1))**4/2.0)))
     &       -ATAN(CONTRAST/(1.-CONTRAST)))
	CTF(II)=DBLE(TMPX)
	ENDDO

	IF(ISEL.EQ.1) THEN

	    INC(:,:)=0
	    	

	      INC(1,1)=1
	    
	      INC(2,2)=1		
	    	
	
cInitilization WE set BB=6, CC=1. and start optimization

	    DO II=1, N

	       A(II,2)=DEXP(ALF(2)*T(II,1))
	       A(II,1)=DEXP(-(T(II,1)*ALF(1))**2)*CTF(II)**2
	       	
	       A(II,5)=DEXP(ALF(2)*T(II,1))*T(II,1)
	       A(II,4)=-2.*DEXP(-(T(II,1)*ALF(1))**2)*ALF(1)*T(II,1)**2
     &   *CTF(II)**2
        
		 			
	    ENDDO
	     
	ENDIF

	IF(ISEL.EQ.2) THEN
	  DO II=1,N
	       A(II,2)=DEXP(ALF(2)*T(II,1))
	       A(II,1)=DEXP(-(T(II,1)*ALF(1))**2)*CTF(II)**2	
	 
	       B(II,1)=DEXP(-(T(II,1)*ALF(1))**2)
	       B(II,2)=DEXP(ALF(2)*T(II,1))
	   
	       ENDDO	
	
	ENDIF

	IF(ISEL.EQ.3) THEN
	  DO II=1,N
	      A(II,5)=B(II,2)*T(II,1)
	      A(II,4)=-2.* B(II,1)*ALF(1)*T(II,1)**2
         
			
	  ENDDO
	ENDIF
	
	ELSE
	
	AA=-3.
	BB=10.8959393613873
	CC=0.043	
	
	DO II=1,N
	  TMPX=SIN(-(QUADPI*(DEFOCUS*XLAMBDA*SNGL(T(II,1))**2-
     &		(CS*XLAMBDA**3*SNGL(T(II,1))**4/2.0)))
     &       -ATAN(CONTRAST/(1.-CONTRAST)))
	CTF(II)=DBLE(TMPX)
	ENDDO

	IF(ISEL.EQ.1) THEN

	    INC(:,:)=0		    	
	
cInitilization WE set BB=6, CC=1. and start optimization

	DO II=1, N

	    PU=Dexp(AA+BB/(T(II,1)/CC+1.)**2)			       
	    A(II,1)=PU*DEXP(-(T(II,1)*XALF1)**2)*CTF(II)**2
	    A(II,2)=XBETA1*DEXP(-(T(II,1)*XALF1)**2)*CTF(II)**2    		 			
	ENDDO
	     
	ENDIF
	
	ENDIF
	END                
cc--------------------------------------------------------------------------------------
	
        SUBROUTINE VARPRO (L, NL, N, NMAX, LPP2, IV, T, Y, W, ADA, A,       
     X IPRINT, ALF, BETA, IERR)                                         
C                                                                       
C           GIVEN A SET OF N OBSERVATIONS, CONSISTING OF VALUES Y(1),   
C        Y(2), ..., Y(N) OF A DEPENDENT VARIABLE Y, WHERE Y(I)          
C        CORRESPONDS TO THE IV INDEPENDENT VARIABLE(S) T(I,1), T(I,2),  
C        ..., T(I,IV), VARPRO ATTEMPTS TO COMPUTE A WEIGHTED LEAST      
C        SQUARES FIT TO A FUNCTION ETA (THE 'MODEL') WHICH IS A LINEAR  
C        COMBINATION                                                    
C                              L                                        CTF1
C       ETA(ALF, BETA; T)  =  SUM  BETA  * PHI (ALF; T) + PHI   (ALF; T)
C                             J=1      J      J              L+1        
C                                                                       
C        OF NONLINEAR FUNCTIONS PHI(J) (E.G., A SUM OF EXPONENTIALS AND/
C        OR GAUSSIANS).  THAT IS, DETERMINE THE LINEAR PARAMETERS       
C        BETA(J) AND THE VECTOR OF NONLINEAR PARAMETERS ALF BY MINIMIZ- 
C        ING                                                            
C                                                                       
C                         2     N                                 2     
C           NORM(RESIDUAL)  =  SUM  W  * (Y  - ETA(ALF, BETA; T )) .    
C                              I=1   I     I                   I        
C                                                                       
C        THE (L+1)-ST TERM IS OPTIONAL, AND IS USED WHEN IT IS DESIRED  
C        TO FIX ONE OR MORE OF THE BETA'S (RATHER THAN LET THEM BE      
C        DETERMINED).  VARPRO REQUIRES FIRST DERIVATIVES OF THE PHI'S.  
C                                                                       
C                                NOTES:                                 
C                                                                       
C        A)  THE ABOVE PROBLEM IS ALSO REFERRED TO AS 'MULTIPLE         
C        NONLINEAR REGRESSION'.  FOR USE IN STATISTICAL ESTIMATION,     
C        VARPRO RETURNS THE RESIDUALS, THE COVARIANCE MATRIX OF THE     
C        LINEAR AND NONLINEAR PARAMETERS, AND THE ESTIMATED VARIANCE OF 
C        THE OBSERVATIONS.                                              
C                                                                       
C        B) AN ETA OF THE ABOVE FORM IS CALLED 'SEPARABLE'.  THE        
C        CASE OF A NONSEPARABLE ETA CAN BE HANDLED BY SETTING L = 0     
C        AND USING PHI(L+1).                                            
C                                                                       
C        C) VARPRO MAY ALSO BE USED TO SOLVE LINEAR LEAST SQUARES       
C        PROBLEMS (IN THAT CASE NO ITERATIONS ARE PERFORMED).  SET      
C        NL = 0.                                                        
C                                                                       
C        D)  THE MAIN ADVANTAGE OF VARPRO OVER OTHER LEAST SQUARES      
C        PROGRAMS IS THAT NO INITIAL GUESSES ARE NEEDED FOR THE LINEAR  
C        PARAMETERS.  NOT ONLY DOES THIS MAKE IT EASIER TO USE, BUT IT  
C        OFTEN LEADS TO FASTER CONVERGENCE.                             
C                                                                       
C                                                                       
C     DESCRIPTION OF PARAMETERS                                         
C                                                                       
C        L       NUMBER OF LINEAR PARAMETERS BETA (MUST BE .GE. 0).     
C        NL      NUMBER OF NONLINEAR PARAMETERS ALF (MUST BE .GE. 0).   
C        N       NUMBER OF OBSERVATIONS.  N MUST BE GREATER THAN L + NL 
C                (I.E., THE NUMBER OF OBSERVATIONS MUST EXCEED THE      
C                NUMBER OF PARAMETERS).                                 
C        IV      NUMBER OF INDEPENDENT VARIABLES T.                     
C        T       REAL N BY IV MATRIX OF INDEPENDENT VARIABLES.  T(I, J) 
C                CONTAINS THE VALUE OF THE I-TH OBSERVATION OF THE J-TH 
C                INDEPENDENT VARIABLE.                                  
C        Y       N-VECTOR OF OBSERVATIONS, ONE FOR EACH ROW OF T.       
C        W       N-VECTOR OF NONNEGATIVE WEIGHTS.  SHOULD BE SET TO 1'S 
C                IF WEIGHTS ARE NOT DESIRED.  IF VARIANCES OF THE       
C                INDIVIDUAL OBSERVATIONS ARE KNOWN, W(I) SHOULD BE SET  
C                TO 1./VARIANCE(I).                                     
C        INC     NL X (L+1) INTEGER INCIDENCE MATRIX.  INC(K, J) = 1 IF 
C                NON-LINEAR PARAMETER ALF(K) APPEARS IN THE J-TH        
C                FUNCTION PHI(J).  (THE PROGRAM SETS ALL OTHER INC(K, J)
C                TO ZERO.)  IF PHI(L+1) IS INCLUDED IN THE MODEL,       
C                THE APPROPRIATE ELEMENTS OF THE (L+1)-ST COLUMN SHOULD 
C                BE SET TO 1'S.  INC IS NOT NEEDED WHEN L = 0 OR NL = 0.
C                CAUTION:  THE DECLARED ROW DIMENSION OF INC (IN ADA)   
C                MUST CURRENTLY BE SET TO 12.  SEE 'RESTRICTIONS' BELOW.
C        NMAX    THE DECLARED ROW DIMENSION OF THE MATRICES A AND T.    
C                IT MUST BE AT LEAST MAX(N, 2*NL+3).                    
C        LPP2    L+P+2, WHERE P IS THE NUMBER OF ONES IN THE MATRIX INC.
C                THE DECLARED COLUMN DIMENSION OF A MUST BE AT LEAST    
C                LPP2.  (IF L = 0, SET LPP2 = NL+2. IF NL = 0, SET LPP2 
C                L+2.)                                                  
C        A       REAL MATRIX OF SIZE MAX(N, 2*NL+3) BY L+P+2.  ON INPUT 
C                IT CONTAINS THE PHI(J)'S AND THEIR DERIVATIVES (SEE    
C                BELOW).  ON OUTPUT, THE FIRST L+NL ROWS AND COLUMNS OF 
C                A WILL CONTAIN AN APPROXIMATION TO THE (WEIGHTED)      
C                COVARIANCE MATRIX AT THE SOLUTION (THE FIRST L ROWS    
C                CORRESPOND TO THE LINEAR PARAMETERS, THE LAST NL TO THE
C                NONLINEAR ONES), COLUMN L+NL+1 WILL CONTAIN THE        
C                WEIGHTED RESIDUALS (Y - ETA), A(1, L+NL+2) WILL CONTAIN
C                THE (EUCLIDEAN) NORM OF THE WEIGHTED RESIDUAL, AND     
C                A(2, L+NL+2) WILL CONTAIN AN ESTIMATE OF THE (WEIGHTED)
C                VARIANCE OF THE OBSERVATIONS, NORM(RESIDUAL)**2/       
C                (N - L - NL).                                          
C        IPRINT  INPUT INTEGER CONTROLLING PRINTED OUTPUT.  IF IPRINT IS
C                POSITIVE, THE NONLINEAR PARAMETERS, THE NORM OF THE    
C                RESIDUAL, AND THE MARQUARDT PARAMETER WILL BE OUTPUT   
C                EVERY IPRINT-TH ITERATION (AND INITIALLY, AND AT THE   
C                FINAL ITERATION).  THE LINEAR PARAMETERS WILL BE       
C                PRINTED AT THE FINAL ITERATION.  ANY ERROR MESSAGES    
C                WILL ALSO BE PRINTED.  (IPRINT = 1 IS RECOMMENDED AT   
C                FIRST.) IF IPRINT = 0, ONLY THE FINAL QUANTITIES WILL  
C                BE PRINTED, AS WELL AS ANY ERROR MESSAGES.  IF IPRINT =
C                -1, NO PRINTING WILL BE DONE.  THE USER IS THEN        
C                RESPONSIBLE FOR CHECKING THE PARAMETER IERR FOR ERRORS.
C        ALF     NL-VECTOR OF ESTIMATES OF NONLINEAR PARAMETERS         

C                (INPUT).  ON OUTPUT IT WILL CONTAIN OPTIMAL VALUES OF  
C                THE NONLINEAR PARAMETERS.                              
C        BETA    L-VECTOR OF LINEAR PARAMETERS (OUTPUT ONLY).           
C        IERR    INTEGER ERROR FLAG (OUTPUT):                           
C                .GT. 0 - SUCCESSFUL CONVERGENCE, IERR IS THE NUMBER OF 
C                    ITERATIONS TAKEN.                                  
C                -1  TERMINATED FOR TOO MANY ITERATIONS.                
C                -2  TERMINATED FOR ILL-CONDITIONING (MARQUARDT         
C                    PARAMETER TOO LARGE.)  ALSO SEE IERR = -8 BELOW.   
C                -4  INPUT ERROR IN PARAMETER N, L, NL, LPP2, OR NMAX.  
C                -5  INC MATRIX IMPROPERLY SPECIFIED, OR P DISAGREES    
C                    WITH LPP2.                                         
C                -6  A WEIGHT WAS NEGATIVE.                             
C                -7  'CONSTANT' COLUMN WAS COMPUTED MORE THAN ONCE.     
C                -8  CATASTROPHIC FAILURE - A COLUMN OF THE A MATRIX HAS
C                    BECOME ZERO.  SEE 'CONVERGENCE FAILURES' BELOW.    
C                                                                       
C                (IF IERR .LE. -4, THE LINEAR PARAMETERS, COVARIANCE    
C                MATRIX, ETC. ARE NOT RETURNED.)                        
C                                                                       
C     SUBROUTINES REQUIRED                                              
C                                                                       
C           NINE SUBROUTINES, VPDPA, VPFAC1, VPFAC2, VPBSOL, VPPOST,    
C        VPCOV ,VPNORM, VPINIT, AND VPERR ARE PROVIDED.  IN ADDITION,   
C        THE USER MUST PROVIDE A SUBROUTINE (CORRESPONDING TO THE ARGU- 
C        MENT ADA) WHICH, GIVEN ALF, WILL EVALUATE THE FUNCTIONS PHI(J) 
C        AND THEIR PARTIAL DERIVATIVES D PHI(J)/D ALF(K), AT THE SAMPLE 
C        POINTS T(I).  THIS ROUTINE MUST BE DECLARED 'EXTERNAL' IN THE  
C        CALLING PROGRAM.  ITS CALLING SEQUENCE IS                      
C                                                                       
C        SUBROUTINE ADA (L+1, NL, N, NMAX, LPP2, IV, A, INC, T, ALF,    
C        ISEL)                                                          
C                                                                       
C           THE USER SHOULD MODIFY THE EXAMPLE SUBROUTINE 'ADA' (GIVEN  
C        ELSEWHERE) FOR HIS OWN FUNCTIONS.                              
C                                                                       
C           THE VECTOR SAMPLED FUNCTIONS PHI(J) SHOULD BE STORED IN THE 
C        FIRST N ROWS AND FIRST L+1 COLUMNS OF THE MATRIX A, I.E.,      
C        A(I, J) SHOULD CONTAIN PHI(J, ALF; T(I,1), T(I,2), ...,        

C        T(I,IV)), I = 1, ..., N; J = 1, ..., L (OR L+1).  THE (L+1)-ST 
C        COLUMN OF A CONTAINS PHI(L+1) IF PHI(L+1) IS IN THE MODEL,     
C        OTHERWISE IT IS RESERVED FOR WORKSPACE.  THE 'CONSTANT' FUNC-  
C        TIONS (THESE ARE FUNCTIONS PHI(J) WHICH DO NOT DEPEND UPON ANY 
C        NONLINEAR PARAMETERS ALF, E.G., T(I)**J) (IF ANY) MUST APPEAR  
C        FIRST, STARTING IN COLUMN 1.  THE COLUMN N-VECTORS OF NONZERO  
C        PARTIAL DERIVATIVES D PHI(J) / D ALF(K) SHOULD BE STORED       
C        SEQUENTIALLY IN THE MATRIX A IN COLUMNS L+2 THROUGH L+P+1.     
C        THE ORDER IS                                                   
C                                                                       
C          D PHI(1)  D PHI(2)        D PHI(L)  D PHI(L+1)  D PHI(1)     
C          --------, --------, ...,  --------, ----------, --------,    
C          D ALF(1)  D ALF(1)        D ALF(1)   D ALF(1)   D ALF(2)     
C                                                                       

C          D PHI(2)       D PHI(L+1)       D PHI(1)        D PHI(L+1)   
C          --------, ..., ----------, ..., ---------, ..., ----------,  
C          D ALF(2)        D ALF(2)        D ALF(NL)       D ALF(NL)    
C                                                                       
C        OMITTING COLUMNS OF DERIVATIVES WHICH ARE ZERO, AND OMITTING   
C        PHI(L+1) COLUMNS IF PHI(L+1) IS NOT IN THE MODEL.  NOTE THAT   
C        THE LINEAR PARAMETERS BETA ARE NOT USED IN THE MATRIX A.       
C        COLUMN L+P+2 IS RESERVED FOR WORKSPACE.                        
C                                                                       
C        THE CODING OF ADA SHOULD BE ARRANGED SO THAT:                  
C                                                                       
C        ISEL = 1  (WHICH OCCURS THE FIRST TIME ADA IS CALLED) MEANS:   
C                  A.  FILL IN THE INCIDENCE MATRIX INC                 
C                  B.  STORE ANY CONSTANT PHI'S IN A.                   
C                  C.  COMPUTE NONCONSTANT PHI'S AND PARTIAL DERIVA-    
C                      TIVES.                                           
C             = 2  MEANS COMPUTE ONLY THE NONCONSTANT FUNCTIONS PHI     
C             = 3  MEANS COMPUTE ONLY THE DERIVATIVES                   
C                                                                       

C        (WHEN THE PROBLEM IS LINEAR (NL = 0) ONLY ISEL = 1 IS USED, AND
C        DERIVATIVES ARE NOT NEEDED.)                                   
C                                                                       
C     RESTRICTIONS                                                      
C                                                                       
C           THE SUBROUTINES VPDPA, VPINIT (AND ADA) CONTAIN THE LOCALLY 
C        DIMENSIONED MATRIX INC, WHOSE DIMENSIONS ARE CURRENTLY SET FOR 
C        MAXIMA OF L+1 = 8, NL = 12.  THEY MUST BE CHANGED FOR LARGER   
C        PROBLEMS.  DATA PLACED IN ARRAY A IS OVERWRITTEN ('DESTROYED').
C        DATA PLACED IN ARRAYS T, Y AND INC IS LEFT INTACT.  THE PROGRAM
C        RUNS IN WATFIV, EXCEPT WHEN L = 0 OR NL = 0.                   
C                                                                       
C           IT IS ASSUMED THAT THE MATRIX PHI(J, ALF; T(I)) HAS FULL    
C        COLUMN RANK.  THIS MEANS THAT THE FIRST L COLUMNS OF THE MATRIX
C        A MUST BE LINEARLY INDEPENDENT.                                
C                                                                       
C           OPTIONAL NOTE:  AS WILL BE NOTED FROM THE SAMPLE SUBPROGRAM 
C        ADA, THE DERIVATIVES D PHI(J)/D ALF(K) (ISEL = 3) MUST BE      
C        COMPUTED INDEPENDENTLY OF THE FUNCTIONS PHI(J) (ISEL = 2),     
C        SINCE THE FUNCTION VALUES ARE OVERWRITTEN AFTER ADA IS CALLED  
C        WITH ISEL = 2.  THIS IS DONE TO MINIMIZE STORAGE, AT THE POS-  
C        SIBLE EXPENSE OF SOME RECOMPUTATION (SINCE THE FUNCTIONS AND   
C        DERIVATIVES FREQUENTLY HAVE SOME COMMON SUBEXPRESSIONS).  TO   
C        REDUCE THE AMOUNT OF COMPUTATION AT THE EXPENSE OF SOME        
C        STORAGE, CREATE A MATRIX B OF DIMENSION NMAX BY L+1 IN ADA, AND
C        AFTER THE COMPUTATION OF THE PHI'S (ISEL = 2), COPY THE VALUES 
C        INTO B.  THESE VALUES CAN THEN BE USED TO CALCULATE THE DERIV- 
C        ATIVES (ISEL = 3).  (THIS MAKES USE OF THE FACT THAT WHEN A    
C        CALL TO ADA WITH ISEL = 3 FOLLOWS A CALL WITH ISEL = 2, THE    
C        ALFS ARE THE SAME.)                                            
C                                                                       
C           TO CONVERT TO OTHER MACHINES, CHANGE THE OUTPUT UNIT IN THE 
C        DATA STATEMENTS IN VARPRO, VPDPA, VPPOST, AND VPERR.  THE      
C        PROGRAM HAS BEEN CHECKED FOR PORTABILITY BY THE BELL LABS PFORT
C        VERIFIER.  FOR MACHINES WITHOUT DOUBLE PRECISION HARDWARE, IT  
C        MAY BE DESIRABLE TO CONVERT TO SINGLE PRECISION.  THIS CAN BE  
C        DONE BY CHANGING (A) THE DECLARATIONS 'DOUBLE PRECISION' TO    
C        'REAL', (B) THE PATTERN '.D' TO '.E' IN THE 'DATA' STATEMENT IN
C        VARPRO, (C) DSIGN, DSQRT AND DABS TO SIGN, SQRT AND ABS,       
C        RESPECTIVELY, AND (D) DEXP TO EXP IN THE SAMPLE PROGRAMS ONLY. 
C                                                                       
C     NOTE ON INTERPRETATION OF COVARIANCE MATRIX                       
C                                                                       
C           FOR USE IN STATISTICAL ESTIMATION (MULTIPLE NONLINEAR       
C        REGRESSION) VARPRO RETURNS THE COVARIANCE MATRIX OF THE LINEAR 
C        AND NONLINEAR PARAMETERS.  THIS MATRIX WILL BE USEFUL ONLY IF  
C        THE USUAL STATISTICAL ASSUMPTIONS HOLD:  AFTER WEIGHTING, THE  
C        ERRORS IN THE OBSERVATIONS ARE INDEPENDENT AND NORMALLY DISTRI-
C        BUTED, WITH MEAN ZERO AND THE SAME VARIANCE.  IF THE ERRORS DO 

C        NOT HAVE MEAN ZERO (OR ARE UNKNOWN), THE PROGRAM WILL ISSUE A  
C        WARNING MESSAGE (UNLESS IPRINT .LT. 0) AND THE COVARIANCE      
C        MATRIX WILL NOT BE VALID.  IN THAT CASE, THE MODEL SHOULD BE   
C        ALTERED TO INCLUDE A CONSTANT TERM (SET PHI(1) = 1.).          
C                                                                       
C           NOTE ALSO THAT, IN ORDER FOR THE USUAL ASSUMPTIONS TO HOLD, 
C        THE OBSERVATIONS MUST ALL BE OF APPROXIMATELY THE SAME         
C        MAGNITUDE (IN THE ABSENCE OF INFORMATION ABOUT THE ERROR OF    
C        EACH OBSERVATION), OTHERWISE THE VARIANCES WILL NOT BE THE     
C        SAME.  IF THE OBSERVATIONS ARE NOT THE SAME SIZE, THIS CAN BE  
C        CURED BY WEIGHTING.                                            
C                                                                       
C           IF THE USUAL ASSUMPTIONS HOLD, THE SQUARE ROOTS OF THE      
C        DIAGONALS OF THE COVARIANCE MATRIX A GIVE THE STANDARD ERROR   

C        S(I) OF EACH PARAMETER.  DIVIDING A(I,J) BY S(I)*S(J) YIELDS   
C        THE CORRELATION MATRIX OF THE PARAMETERS.  PRINCIPAL AXES AND  
C        CONFIDENCE ELLIPSOIDS CAN BE OBTAINED BY PERFORMING AN EIGEN-  
C        VALUE/EIGENVECTOR ANALYSIS ON A.  ONE SHOULD CALL THE EISPACK  
C        PROGRAM TRED2, FOLLOWED BY TQL2 (OR USE THE EISPAC CONTROL     
C        PROGRAM).                                                      
C                                                                       
C     CONVERGENCE FAILURES                                              
C                                                                       
C           IF CONVERGENCE FAILURES OCCUR, FIRST CHECK FOR INCORRECT    
C        CODING OF THE SUBROUTINE ADA.  CHECK ESPECIALLY THE ACTION OF  
C        ISEL, AND THE COMPUTATION OF THE PARTIAL DERIVATIVES.  IF THESE
C        ARE CORRECT, TRY SEVERAL STARTING GUESSES FOR ALF.  IF ADA     
C        IS CODED CORRECTLY, AND IF ERROR RETURNS IERR = -2 OR -8       
C        PERSISTENTLY OCCUR, THIS IS A SIGN OF ILL-CONDITIONING, WHICH  
C        MAY BE CAUSED BY SEVERAL THINGS.  ONE IS POOR SCALING OF THE   
C        PARAMETERS; ANOTHER IS AN UNFORTUNATE INITIAL GUESS FOR THE    
C        PARAMETERS, STILL ANOTHER IS A POOR CHOICE OF THE MODEL.       
C                                                                       
C     ALGORITHM                                                         
C                                                                       
C           THE RESIDUAL R IS MODIFIED TO INCORPORATE, FOR ANY FIXED    
C        ALF, THE OPTIMAL LINEAR PARAMETERS FOR THAT ALF.  IT IS THEN   
C        POSSIBLE TO MINIMIZE ONLY ON THE NONLINEAR PARAMETERS.  AFTER  
C        THE OPTIMAL VALUES OF THE NONLINEAR PARAMETERS HAVE BEEN DETER-
C        MINED, THE LINEAR PARAMETERS CAN BE RECOVERED BY LINEAR LEAST  
C        SQUARES TECHNIQUES (SEE REF. 1).                               
C                                                                       
C           THE MINIMIZATION IS BY A MODIFICATION OF OSBORNE'S (REF. 3) 
C        MODIFICATION OF THE LEVENBERG-MARQUARDT ALGORITHM.  INSTEAD OF 
C        SOLVING THE NORMAL EQUATIONS WITH MATRIX                       
C                                                                       
C                 T      2                                              
C               (J J + NU  * D),      WHERE  J = D(ETA)/D(ALF),         
C                                                                       
C        STABLE ORTHOGONAL (HOUSEHOLDER) REFLECTIONS ARE USED ON A      
C        MODIFICATION OF THE MATRIX                                     
C                                   (   J  )                            
C                                   (------) ,                          
C                                   ( NU*D )                            
C                                                                       
C        WHERE D IS A DIAGONAL MATRIX CONSISTING OF THE LENGTHS OF THE  
C        COLUMNS OF J.  THIS MARQUARDT STABILIZATION ALLOWS THE ROUTINE 
C        TO RECOVER FROM SOME RANK DEFICIENCIES IN THE JACOBIAN.        
C        OSBORNE'S EMPIRICAL STRATEGY FOR CHOOSING THE MARQUARDT PARAM- 
C        ETER HAS PROVEN REASONABLY SUCCESSFUL IN PRACTICE.  (GAUSS-    
C        NEWTON WITH STEP CONTROL CAN BE OBTAINED BY MAKING THE CHANGE  
C        INDICATED BEFORE THE INSTRUCTION LABELED 5).  A DESCRIPTION CAN
C        BE FOUND IN REF. (3), AND A FLOW CHART IN (2), P. 22.          
C                                                                       
C        FOR REFERENCE, SEE                                             
C                                                                       
C        1.  GENE H. GOLUB AND V. PEREYRA, 'THE DIFFERENTIATION OF      
C            PSEUDO-INVERSES AND NONLINEAR LEAST SQUARES PROBLEMS WHOSE 
C            VARIABLES SEPARATE,' SIAM J. NUMER. ANAL. 10, 413-432      
C            (1973).                                                    
C        2.  ------, SAME TITLE, STANFORD C.S. REPORT 72-261, FEB. 1972.
C        3.  OSBORNE, MICHAEL R., 'SOME ASPECTS OF NON-LINEAR LEAST     
C            SQUARES CALCULATIONS,' IN LOOTSMA, ED., 'NUMERICAL METHODS 
C            FOR NON-LINEAR OPTIMIZATION,' ACADEMIC PRESS, LONDON, 1972.
C        4.  KROGH, FRED, 'EFFICIENT IMPLEMENTATION OF A VARIABLE PRO-  
C            JECTION ALGORITHM FOR NONLINEAR LEAST SQUARES PROBLEMS,'   
C            COMM. ACM 17, PP. 167-169 (MARCH, 1974).                   
C        5.  KAUFMAN, LINDA, 'A VARIABLE PROJECTION METHOD FOR SOLVING  
C            SEPARABLE NONLINEAR LEAST SQUARES PROBLEMS', B.I.T. 15,    
C            49-57 (1975).                                              
C        6.  DRAPER, N., AND SMITH, H., APPLIED REGRESSION ANALYSIS,    
C            WILEY, N.Y., 1966 (FOR STATISTICAL INFORMATION ONLY).      
C        7.  C. LAWSON AND R. HANSON, SOLVING LEAST SQUARES PROBLEMS,   
C            PRENTICE-HALL, ENGLEWOOD CLIFFS, N. J., 1974.              
C                                                                       
C                      JOHN BOLSTAD                                     
C                      COMPUTER SCIENCE DEPT., SERRA HOUSE              
C                      STANFORD UNIVERSITY                              
C                      JANUARY, 1977                                    
C                                                                       
C     ..................................................................
C                                                                       
      DOUBLE PRECISION A(NMAX, LPP2), BETA(L), ALF(NL), T(NMAX, IV),    
     &    W(N), Y(N), ACUM, EPS1, GNSTEP, NU, PRJRES, R, RNEW, VPNORM      
      INTEGER B1, OUTPUT                                                
      LOGICAL SKIP                                                      
      EXTERNAL ADA                                                      
      DATA EPS1 /1.D-6/, ITMAX /50/, OUTPUT /6/                         
C                                                                       
C           THE FOLLOWING TWO PARAMETERS ARE USED IN THE CONVERGENCE    
C           TEST:  EPS1 IS AN ABSOLUTE AND RELATIVE TOLERANCE FOR THE   
C           NORM OF THE PROJECTION OF THE RESIDUAL ONTO THE RANGE OF THE
C           JACOBIAN OF THE VARIABLE PROJECTION FUNCTIONAL.             
C           ITMAX IS THE MAXIMUM NUMBER OF FUNCTION AND DERIVATIVE      
C           EVALUATIONS ALLOWED.  CAUTION:  EPS1 MUST NOT BE            
C           SET SMALLER THAN 10 TIMES THE UNIT ROUND-OFF OF THE MACHINE.
C                                                                       
C-----------------------------------------------------------------      
CALL LIB MONITOR FROM VARPRO, MAINTENANCE NUMBER 509, DATE 77178        
C        CALL LIBMON(509)                                               
C***PLEASE DON'T REMOVE OR CHANGE THE ABOVE CALL. IT IS YOUR ONLY       
C***PROTECTION AGAINST YOUR USING AN OUT-OF-DATE OR INCORRECT           
C***VERSION OF THE ROUTINE. THE LIBRARY MONITOR REMOVES THIS CALL,      
C***SO IT ONLY OCCURS ONCE, ON THE FIRST ENTRY TO THIS ROUTINE.         
C-----------------------------------------------------------------      
      IERR = 1                                                          
      ITER = 0                                                          
      LP1 = L + 1                                                       
      B1 = L + 2                                                        
      LNL2 = L + NL + 2                                                 
      NLP1 = NL + 1                                                     
      SKIP = .FALSE.                                                    
      MODIT = IPRINT                                                    
      IF (IPRINT .LE. 0) MODIT = ITMAX + 2                              
      NU = 0.                                                           
C              IF GAUSS-NEWTON IS DESIRED REMOVE THE NEXT STATEMENT.    
      NU = 1.                                                           
C                                                                       
C              BEGIN OUTER ITERATION LOOP TO UPDATE ALF.                
C              CALCULATE THE NORM OF THE RESIDUAL AND THE DERIVATIVE OF 
C              THE MODIFIED RESIDUAL THE FIRST TIME, BUT ONLY THE       
C              DERIVATIVE IN SUBSEQUENT ITERATIONS.                     
C                                                                       
    5 CALL VPDPA (L, NL, N, NMAX, LPP2, IV, T, Y, W, ALF, ADA, IERR,    
     X IPRINT, A, BETA, A(1, LP1), R)                                   
      GNSTEP = 1.0                                                      
      ITERIN = 0                                                        
      IF (ITER .GT. 0) GO TO 10                                         
         IF (NL .EQ. 0) GO TO 90                                        
         IF (IERR .NE. 1) GO TO 99                                      
C                                                                       
         IF (IPRINT .LE. 0) GO TO 10                                    
         WRITE (OUTPUT, 207) ITERIN, R                                  
         WRITE (OUTPUT, 200) NU                                         
C                              BEGIN TWO-STAGE ORTHOGONAL FACTORIZATION 
   10 CALL VPFAC1(NLP1, NMAX, N, L, IPRINT, A(1, B1), PRJRES, IERR)     
      IF (IERR .LT. 0) GO TO 99                                         
      IERR = 2                                                          
      IF (NU .EQ. 0.) GO TO 30                                          
C                                                                       
C              BEGIN INNER ITERATION LOOP FOR GENERATING NEW ALF AND    
C              TESTING IT FOR ACCEPTANCE.                               
C                                                                       
   25    CALL VPFAC2(NLP1, NMAX, NU, A(1, B1))                          
C                                                                       
C              SOLVE A NL X NL UPPER TRIANGULAR SYSTEM FOR DELTA-ALF.   
C              THE TRANSFORMED RESIDUAL (IN COL. LNL2 OF A) IS OVER-    
C              WRITTEN BY THE RESULT DELTA-ALF.                         
C                                                                       
   30    CALL VPBSOL (NMAX, NL, A(1, B1), A(1, LNL2))                   
         DO 35 K = 1, NL                                                
   35       A(K, B1)  = ALF(K) + A(K, LNL2)                             
C           NEW ALF(K) = ALF(K) + DELTA ALF(K)                          
C                                                                       
C              STEP TO THE NEW POINT NEW ALF, AND COMPUTE THE NEW       
C              NORM OF RESIDUAL.  NEW ALF IS STORED IN COLUMN B1 OF A.  
C                                                                       
   40    CALL VPDPA (L, NL, N, NMAX, LPP2, IV, T, Y, W, A(1, B1), ADA,  
     X   IERR, IPRINT, A, BETA, A(1, LP1), RNEW)                        
         IF (IERR .NE. 2) GO TO 99                                      
         ITER = ITER + 1                                                
         ITERIN = ITERIN + 1                                            
         SKIP = MOD(ITER, MODIT) .NE. 0                                 
         IF (SKIP) GO TO 45                                             
            WRITE (OUTPUT, 203) ITER                                    
            WRITE (OUTPUT, 216) (A(K, B1), K = 1, NL)                   
            WRITE (OUTPUT, 207) ITERIN, RNEW                            
C                                                                       
   45    IF (ITER .LT. ITMAX) GO TO 50                                  
            IERR = -1                                                   
            CALL VPERR (IPRINT, IERR, 1)                                
            GO TO 95                                                    
   50    IF (RNEW - R .LT. EPS1*(R + 1.D0)) GO TO 75                    
C                                                                       
C              RETRACT THE STEP JUST TAKEN                              
C                                                                       
            IF (NU .NE. 0.) GO TO 60                                    
C                                             GAUSS-NEWTON OPTION ONLY  
            GNSTEP = 0.5*GNSTEP                                         
            IF (GNSTEP .LT. EPS1) GO TO 95                              
            DO 55 K = 1, NL                                             
   55          A(K, B1) = ALF(K) + GNSTEP*A(K, LNL2)                    
            GO TO 40                                                    
C                                        ENLARGE THE MARQUARDT PARAMETER
   60       NU = 1.5*NU                                                 
            IF (.NOT. SKIP) WRITE (OUTPUT, 206) NU                      
            IF (NU .LE. 100.) GO TO 65                                  
               IERR = -2                                                
               CALL VPERR (IPRINT, IERR, 1)                             
               GO TO 95                                                 
C                                        RETRIEVE UPPER TRIANGULAR FORM 
C                                        AND RESIDUAL OF FIRST STAGE.   
   65    DO 70 K = 1, NL                                                
            KSUB = LP1 + K                                              
            DO 70 J = K, NLP1                                           
               JSUB = LP1 + J                                           
               ISUB = NLP1 + J                                          
   70          A(K, JSUB) = A(ISUB, KSUB)                               
         GO TO 25                                                       
C                                        END OF INNER ITERATION LOOP    
C           ACCEPT THE STEP JUST TAKEN                                  
C                                                                       
   75 R = RNEW                                                          
      DO 80 K = 1, NL                                                   
   80    ALF(K) = A(K, B1)                                              
C                                        CALC. NORM(DELTA ALF)/NORM(ALF)
      ACUM = GNSTEP*VPNORM(NL, A(1, LNL2))/VPNORM(NL, ALF)              
C                                                                       
C           IF ITERIN IS GREATER THAN 1, A STEP WAS RETRACTED DURING    
C           THIS OUTER ITERATION.                                       
C                                                                       
      IF (ITERIN .EQ. 1) NU = 0.5*NU                                    
      IF (SKIP) GO TO 85                                                
         WRITE (OUTPUT, 200) NU                                         
         WRITE (OUTPUT, 208) ACUM                                       
   85 IERR = 3                                                          
      IF (PRJRES .GT. EPS1*(R + 1.D0)) GO TO 5                          
C           END OF OUTER ITERATION LOOP                                 
C                                                                       
C           CALCULATE FINAL QUANTITIES -- LINEAR PARAMETERS, RESIDUALS, 
C           COVARIANCE MATRIX, ETC.                                     
C                                                                       
   90 IERR = ITER                                                       
   95 IF (NL .GT. 0) CALL VPDPA(L, NL, N, NMAX, LPP2, IV, T, Y, W, ALF, 
     X ADA, 4, IPRINT, A, BETA, A(1, LP1), R)                           
      CALL VPPOST(L, NL, N, NMAX, LNL2, EPS1, R, IPRINT, ALF, W, A,     
     X A(1, LP1), BETA, IERR)                                           
   99 RETURN                                                            
C                                                                       
  200 FORMAT (9H     NU =, E15.7)                                       
  203 FORMAT (12H0  ITERATION, I4, 24H    NONLINEAR PARAMETERS)         
  206 FORMAT (25H     STEP RETRACTED, NU =, E15.7)                      
  207 FORMAT (1H0, I5, 20H  NORM OF RESIDUAL =, E15.7)                  
  208 FORMAT (34H     NORM(DELTA-ALF) / NORM(ALF) =, E12.3)             
  216 FORMAT (1H0, 7E15.7)                                              
      END                                                               
C                                                                       
      SUBROUTINE VPFAC1(NLP1, NMAX, N, L, IPRINT, B, PRJRES, IERR)      
C                                                                       
C            STAGE 1:  HOUSEHOLDER REDUCTION OF                         
C                                                                       
C                   (    .    )      ( DR'. R3 )    NL                  
C                   ( DR . R2 )  TO  (----. -- ),                       
C                   (    .    )      (  0 . R4 )  N-L-NL                
C                                                                       
C                     NL    1          NL   1                           
C                                                                       
C         WHERE DR = -D(Q2)*Y IS THE DERIVATIVE OF THE MODIFIED RESIDUAL
C         PRODUCED BY VPDPA, R2 IS THE TRANSFORMED RESIDUAL FROM DPA,   
C         AND DR' IS IN UPPER TRIANGULAR FORM (AS IN REF. (2), P. 18).  
C         DR IS STORED IN ROWS L+1 TO N AND COLUMNS L+2 TO L + NL + 1 OF
C         THE MATRIX A (I.E., COLUMNS 1 TO NL OF THE MATRIX B).  R2 IS  
C         STORED IN COLUMN L + NL + 2 OF THE MATRIX A (COLUMN NL + 1 OF 
C         B).  FOR K = 1, 2, ..., NL, FIND REFLECTION I - U * U' / BETA 
C         WHICH ZEROES B(I, K), I = L+K+1, ..., N.                      
C                                                                       
C     ..................................................................
C                                                                       
      DOUBLE PRECISION ACUM, ALPHA, B(NMAX, NLP1), BETA, DSIGN, PRJRES, 
     X U, VPNORM                                                        
C                                                                       
      NL = NLP1 - 1                                                     
      NL23 = 2*NL + 3                                                   
      LP1 = L + 1                                                       
C                                                                       
      DO 30 K = 1, NL                                                   
         LPK = L + K                                                    
         ALPHA = DSIGN(VPNORM(N+1-LPK, B(LPK, K)), B(LPK, K))           
         U = B(LPK, K) + ALPHA                                          
         B(LPK, K) = U                                                  
         BETA = ALPHA * U                                               
         IF (ALPHA .NE. 0.0) GO TO 13                                   
C                                                   COLUMN WAS ZERO     
         IERR = -8                                                      
         CALL VPERR (IPRINT, IERR, LP1 + K)                             
         GO TO 99                                                       
C                                APPLY REFLECTIONS TO REMAINING COLUMNS 
C                                OF B AND TO RESIDUAL VECTOR.           
   13    KP1 = K + 1                                                    
         DO 25 J = KP1, NLP1                                            
            ACUM = 0.0                                                  
            DO 20 I = LPK, N                                            
   20          ACUM = ACUM + B(I, K) * B(I, J)                          
            ACUM = ACUM / BETA                                          
            DO 25 I = LPK, N                                            
   25          B(I, J) = B(I, J) - B(I, K) * ACUM                       
   30    B(LPK, K) = -ALPHA                                             
C                                                                       
      PRJRES = VPNORM(NL, B(LP1, NLP1))                                 
C                                                                       
C           SAVE UPPER TRIANGULAR FORM AND TRANSFORMED RESIDUAL, FOR USE
C           IN CASE A STEP IS RETRACTED.  ALSO COMPUTE COLUMN LENGTHS.  
C                                                                       
      IF (IERR .EQ. 4) GO TO 99                                         
      DO 50 K = 1, NL                                                   
         LPK = L + K                                                    
         DO 40 J = K, NLP1                                              
            JSUB = NLP1 + J                                             
            B(K, J) = B(LPK, J)                                         
   40       B(JSUB, K) = B(LPK, J)                                      
   50    B(NL23, K) = VPNORM(K, B(LP1, K))                              
C                                                                       
   99 RETURN                                                            
      END                                                               
C                                                                       
      SUBROUTINE VPFAC2(NLP1, NMAX, NU, B)                              
C                                                                       
C        STAGE 2:  SPECIAL HOUSEHOLDER REDUCTION OF                     
C                                                                       
C                      NL     ( DR' . R3 )      (DR'' . R5 )            
C                             (-----. -- )      (-----. -- )            
C                  N-L-NL     (  0  . R4 )  TO  (  0  . R4 )            
C                             (-----. -- )      (-----. -- )            
C                      NL     (NU*D . 0  )      (  0  . R6 )            
C                                                                       
C                                NL    1          NL    1               
C                                                                       
C        WHERE DR', R3, AND R4 ARE AS IN VPFAC1, NU IS THE MARQUARDT    
C        PARAMETER, D IS A DIAGONAL MATRIX CONSISTING OF THE LENGTHS OF 
C        THE COLUMNS OF DR', AND DR'' IS IN UPPER TRIANGULAR FORM.      
C        DETAILS IN (1), PP. 423-424.  NOTE THAT THE (N-L-NL) BAND OF   
C        ZEROES, AND R4, ARE OMITTED IN STORAGE.                        
C                                                                       
C     ..................................................................
C                                                                       
      DOUBLE PRECISION ACUM, ALPHA, B(NMAX, NLP1), BETA, DSIGN, NU, U,  
     X VPNORM                                                           
C                                                                       
      NL = NLP1 - 1                                                     
      NL2 = 2*NL                                                        
      NL23 = NL2 + 3                                                    
      DO 30 K = 1, NL                                                   
         KP1 = K + 1                                                    
         NLPK = NL + K                                                  
         NLPKM1 = NLPK - 1                                              
         B(NLPK, K) = NU * B(NL23, K)                                   
         B(NL, K) = B(K, K)                                             
         ALPHA = DSIGN(VPNORM(K+1, B(NL, K)), B(K, K))                  
         U = B(K, K) + ALPHA                                            
         BETA = ALPHA * U                                               
         B(K, K) = -ALPHA                                               
C                        THE K-TH REFLECTION MODIFIES ONLY ROWS K,      
C                        NL+1, NL+2, ..., NL+K, AND COLUMNS K TO NL+1.  
         DO 30 J = KP1, NLP1                                            
            B(NLPK, J) = 0.                                             
            ACUM = U * B(K,J)                                           
            DO 20 I = NLP1, NLPKM1                                      
   20          ACUM = ACUM + B(I,K) * B(I,J)                            
            ACUM = ACUM / BETA                                          
            B(K,J) = B(K,J) - U * ACUM                                  
            DO 30 I = NLP1, NLPK                                        
   30          B(I,J) = B(I,J) - B(I,K) * ACUM                          
C                                                                       
      RETURN                                                            
      END                                                               
C                                                                       
      SUBROUTINE VPDPA (L, NL, N, NMAX, LPP2, IV, T, Y, W, ALF, ADA,    
     X ISEL, IPRINT, A, U, R, RNORM)                                    
C                                                                       
C        COMPUTE THE NORM OF THE RESIDUAL (IF ISEL = 1 OR 2), OR THE    
C        (N-L) X NL DERIVATIVE OF THE MODIFIED RESIDUAL (N-L) VECTOR    
C        Q2*Y (IF ISEL = 1 OR 3).  HERE Q * PHI = S, I.E.,              
C                                                                       
C         L     ( Q1 ) (     .   .        )   ( S  . R1 .  F1  )        
C               (----) ( PHI . Y . D(PHI) ) = (--- . -- . ---- )        
C         N-L   ( Q2 ) (     .   .        )   ( 0  . R2 .  F2  )        
C                                                                       
C                 N       L    1      P         L     1     P           
C                                                                       
C        WHERE Q IS N X N ORTHOGONAL, AND S IS L X L UPPER TRIANGULAR.  
C        THE NORM OF THE RESIDUAL = NORM(R2), AND THE DESIRED DERIVATIVE
C        ACCORDING TO REF. (5), IS                                      
C                                               -1                      
C                    D(Q2 * Y) = -Q2 * D(PHI)* S  * Q1* Y.              
C                                                                       
C     ..................................................................
C                                                                       
      DOUBLE PRECISION A(NMAX, LPP2), ALF(NL), T(NMAX, IV), W(N), Y(N), 
     X ACUM, ALPHA, BETA, RNORM, DSIGN, DSQRT, SAVE, R(N), U(L), VPNORM 
      INTEGER FIRSTC, FIRSTR, INC(12, 8)                                
      LOGICAL NOWATE, PHILP1                                            
      EXTERNAL ADA                                                      
C                                                                       
      IF (ISEL .NE. 1) GO TO 3                                          
         LP1 = L + 1                                                    
         LNL2 = L + 2 + NL                                              
         LP2 = L + 2                                                    
         LPP1 = LPP2 - 1                                                
         FIRSTC = 1                                                     
         LASTC = LPP1                                                   
         FIRSTR = LP1                                                   
         CALL VPINIT(L, NL, N, NMAX, LPP2, IV, T, W, ALF, ADA, ISEL,    
     X   IPRINT, A, INC, NCON, NCONP1, PHILP1, NOWATE)
	    
         IF (ISEL .NE. 1) GO TO 99                                      
         GO TO 30                                                       
C                                                                       
    3 CALL ADA (LP1, NL, N, NMAX, LPP2, IV, A, INC, T, ALF, MIN0(ISEL,  
     X 3))                                                              
      IF (ISEL .EQ. 2) GO TO 6                                          
C                                                 ISEL = 3 OR 4         
      FIRSTC = LP2                                                      
      LASTC = LPP1                                                      
      FIRSTR = (4 - ISEL)*L + 1                                         
      GO TO 50                                                          
C                                                 ISEL = 2              
    6 FIRSTC = NCONP1                                                   
      LASTC = LP1                                                       
      IF (NCON .EQ. 0) GO TO 30                                         
      IF (A(1, NCON) .EQ. SAVE) GO TO 30  
	print *,'NCON',ISEL                              
         ISEL = -7                                           
         CALL VPERR (IPRINT, ISEL, NCON)                                
         GO TO 99                                                       
C                                                  ISEL = 1 OR 2        
   30 IF (PHILP1) GO TO 40                                              
         DO 35 I = 1, N                                                 
   35       R(I) = Y(I)                                                 
         GO TO 50                                                       
   40    DO 45 I = 1, N                                                 
   45       R(I) = Y(I) - R(I)                                          
C                                             WEIGHT APPROPRIATE COLUMNS
   50 IF (NOWATE) GO TO 58                                              
      DO 55 I = 1, N                                                    
         ACUM = W(I)                                                    
         DO 55 J = FIRSTC, LASTC                                        
   55       A(I, J) = A(I, J) * ACUM                                    
C                                                                       
C           COMPUTE ORTHOGONAL FACTORIZATIONS BY HOUSEHOLDER            
C           REFLECTIONS.  IF ISEL = 1 OR 2, REDUCE PHI (STORED IN THE   
C           FIRST L COLUMNS OF THE MATRIX A) TO UPPER TRIANGULAR FORM,  
C           (Q*PHI = S), AND TRANSFORM Y (STORED IN COLUMN L+1), GETTING
C           Q*Y = R.  IF ISEL = 1, ALSO TRANSFORM J = D PHI (STORED IN  
C           COLUMNS L+2 THROUGH L+P+1 OF THE MATRIX A), GETTING Q*J = F.
C           IF ISEL = 3 OR 4, PHI HAS ALREADY BEEN REDUCED, TRANSFORM   
C           ONLY J.  S, R, AND F OVERWRITE PHI, Y, AND J, RESPECTIVELY, 
C           AND A FACTORED FORM OF Q IS SAVED IN U AND THE LOWER        
C           TRIANGLE OF PHI.                                            
C                                                                       
   58 IF (L .EQ. 0) GO TO 75                                            
      DO 70 K = 1, L                                                    
         KP1 = K + 1                                                    
         IF (ISEL .GE. 3 .OR. (ISEL .EQ. 2 .AND. K .LT.NCONP1)) GO TO 66
         ALPHA = DSIGN(VPNORM(N+1-K, A(K, K)), A(K, K))                 
         U(K) = A(K, K) + ALPHA                                         
         A(K, K) = -ALPHA                                               
         FIRSTC = KP1                                                   
         IF (ALPHA .NE. 0.0) GO TO 66                                   
         ISEL = -8                                                      
         CALL VPERR (IPRINT, ISEL, K)                                   
         GO TO 99                                                       
C                                        APPLY REFLECTIONS TO COLUMNS   
C                                        FIRSTC TO LASTC.               
   66    BETA = -A(K, K) * U(K)                                         
         DO 70 J = FIRSTC, LASTC                                        
            ACUM = U(K)*A(K, J)                                         
            DO 68 I = KP1, N                                            
   68          ACUM = ACUM + A(I, K)*A(I, J)                            
            ACUM = ACUM / BETA                                          
            A(K,J) = A(K,J) - U(K)*ACUM                                 
            DO 70 I = KP1, N                                            
   70          A(I, J) = A(I, J) - A(I, K)*ACUM                         
C                                                                       
   75 IF (ISEL .GE. 3) GO TO 85                                         
      RNORM = VPNORM(N-L, R(LP1))                                       
      IF (ISEL .EQ. 2) GO TO 99                                         
      IF (NCON .GT. 0) SAVE = A(1, NCON)                                
C                                                                       
C           F2 IS NOW CONTAINED IN ROWS L+1 TO N AND COLUMNS L+2 TO     
C           L+P+1 OF THE MATRIX A.  NOW SOLVE THE L X L UPPER TRIANGULAR
C           SYSTEM S*BETA = R1 FOR THE LINEAR PARAMETERS BETA.  BETA    
C           OVERWRITES R1.                                              
C                                                                       
   85 IF (L .GT. 0) CALL VPBSOL (NMAX, L, A, R)                         
C                                                                       
C           MAJOR PART OF KAUFMAN'S SIMPLIFICATION OCCURS HERE.  COMPUTE
C           THE DERIVATIVE OF ETA WITH RESPECT TO THE NONLINEAR         
C           PARAMETERS                                                  
C                                                                       
C   T   D ETA        T    L          D PHI(J)    D PHI(L+1)             
C  Q * --------  =  Q * (SUM BETA(J) --------  + ----------)  =  F2*BETA
C      D ALF(K)          J=1         D ALF(K)     D ALF(K)              
C                                                                       
C           AND STORE THE RESULT IN COLUMNS L+2 TO L+NL+1.  IF ISEL NOT 
C           = 4, THE FIRST L ROWS ARE OMITTED.  THIS IS -D(Q2)*Y.  IF   
C           ISEL NOT = 4 THE RESIDUAL R2 = Q2*Y (IN COL. L+1) IS COPIED 
C           TO COLUMN L+NL+2.  OTHERWISE ALL OF COLUMN L+1 IS COPIED.   
C                                                                       
      DO 95 I = FIRSTR, N                                               
         IF (L .EQ. NCON) GO TO 95                                      
         M = LP1                                                        
         DO 90 K = 1, NL                                                
            ACUM = 0.                                                   
            DO 88 J = NCONP1, L                                         
               IF (INC(K, J) .EQ. 0) GO TO 88                           
               M = M + 1                                                
               ACUM = ACUM + A(I, M) * R(J)                             
   88          CONTINUE                                                 
            KSUB = LP1 + K                                              
            IF (INC(K, LP1) .EQ. 0) GO TO 90                            
            M = M + 1                                                   
            ACUM = ACUM + A(I, M)                                       
   90       A(I, KSUB) = ACUM                                           
   95    A(I, LNL2) = R(I)                                              
C                                                                       
   99 RETURN                                                            
      END                                                               
CCC========================================================================                                                                       
      SUBROUTINE VPINIT(L, NL, N, NMAX, LPP2, IV, T, W, ALF, ADA, ISEL, 
     X IPRINT, A, INC, NCON, NCONP1, PHILP1, NOWATE)                    
C                                                                       
C        CHECK VALIDITY OF INPUT PARAMETERS, AND DETERMINE NUMBER OF    
C        CONSTANT FUNCTIONS.                                            
C                                                                       
C     ..................................................................
C                                                                       
      DOUBLE PRECISION A(NMAX, LPP2), ALF(NL), T(NMAX, IV), W(N),       
     X DSQRT                                                            
      INTEGER OUTPUT, P, INC(12, 8)                                     
      LOGICAL NOWATE, PHILP1                                            
      DATA OUTPUT /6/                                                   
C                                                                       
      LP1 = L + 1                                                       
      LNL2 = L + 2 + NL                                                 
C                                          CHECK FOR VALID INPUT        
      IF (L .GE. 0 .AND. NL .GE. 0 .AND. L+NL .LT. N .AND. LNL2 .LE.    
     X LPP2 .AND. 2*NL + 3 .LE. NMAX .AND. N .LE. NMAX .AND.            
     X IV .GT. 0 .AND. .NOT. (NL .EQ. 0 .AND. L .EQ. 0)) GO TO 1        
         ISEL = -4                                                      
         CALL VPERR (IPRINT, ISEL, 1)                                   
         GO TO 99                                                       
C                                                                       
    1 IF (L .EQ. 0 .OR. NL .EQ. 0) GO TO 3                              
         DO 2 J = 1, LP1                                                
            DO 2 K = 1, NL                                              
    2          INC(K, J) = 0                                            
C                                                                       
    3 CALL ADA (LP1, NL, N, NMAX, LPP2, IV, A, INC, T, ALF, ISEL)       
C                                                                       
      NOWATE = .TRUE.                                                   
      DO 9 I = 1, N                                                     
         NOWATE = NOWATE .AND. (W(I) .EQ. 1.0)                          
         IF (W(I) .GE. 0.) GO TO 9                                      
C                                                ERROR IN WEIGHTS       
         ISEL = -6                                                      
         CALL VPERR (IPRINT, ISEL, I)                                   
         GO TO 99                                                       
    9    W(I) = DSQRT(W(I))                                             
C                                                                       
      NCON = L                                                          
      NCONP1 = LP1                                                      
      PHILP1 = L .EQ. 0                                                 
      IF (PHILP1 .OR. NL .EQ. 0) GO TO 99                               
C                                   CHECK INC MATRIX FOR VALID INPUT AND
C                                   DETERMINE NUMBER OF CONSTANT FCNS.  
      P = 0                                                             
      DO 11 J = 1, LP1                                                  
         IF (P .EQ. 0) NCONP1 = J                                       
         DO 11 K = 1, NL                                                
            INCKJ = INC(K, J)                                           
            IF (INCKJ .NE. 0 .AND. INCKJ .NE. 1) GO TO 15               
            IF (INCKJ .EQ. 1) P = P + 1                                 
   11       CONTINUE                                                    
C                                                                       
      NCON = NCONP1 - 1                                                 
      IF (IPRINT .GE. 0) WRITE (OUTPUT, 210) NCON                       
      IF (L+P+2 .EQ. LPP2) GO TO 20                                     
C                                              INPUT ERROR IN INC MATRIX
   15 ISEL = -5                                                         
      CALL VPERR (IPRINT, ISEL, 1)                                      
      GO TO 99                                                          
C                                 DETERMINE IF PHI(L+1) IS IN THE MODEL.
   20 DO 25 K = 1, NL                                                   
   25    IF (INC(K, LP1) .EQ. 1) PHILP1 = .TRUE.                        
C                                                                       
   99 RETURN                                                            
  210 FORMAT (33H0  NUMBER OF CONSTANT FUNCTIONS =, I4 /)               
      END            
cccc===========================================================================================                                                   
      SUBROUTINE VPBSOL (NMAX, N, A, X)                                 
C                                                                       
C        BACKSOLVE THE N X N UPPER TRIANGULAR SYSTEM A*X = B.           
C        THE SOLUTION X OVERWRITES THE RIGHT SIDE B.                    
C                                                                       
      DOUBLE PRECISION A(NMAX, N), X(N), ACUM                           
C                                                                       
      X(N) = X(N) / A(N, N)                                             
      IF (N .EQ. 1) GO TO 30                                            
      NP1 = N + 1                                                       
      DO 20 IBACK = 2, N                                                
         I = NP1 - IBACK                                                
C           I = N-1, N-2, ..., 2, 1                                     
         IP1 = I + 1                                                    
         ACUM = X(I)                                                    
         DO 10 J = IP1, N                                               
   10       ACUM = ACUM - A(I,J)*X(J)                                   
   20    X(I) = ACUM / A(I,I)                                           
C                                                                       
   30 RETURN                                                            
      END                                                               
      SUBROUTINE VPPOST(L, NL, N, NMAX, LNL2, EPS, RNORM, IPRINT, ALF,  
     X W, A, R, U, IERR)                                                
C                                                                       
C        CALCULATE RESIDUALS, SAMPLE VARIANCE, AND COVARIANCE MATRIX.   
C        ON INPUT, U CONTAINS INFORMATION ABOUT HOUSEHOLDER REFLECTIONS 
C        FROM VPDPA.  ON OUTPUT, IT CONTAINS THE LINEAR PARAMETERS.     
C                                                                       
      DOUBLE PRECISION A(NMAX, LNL2), ALF(NL), R(N), U(L), W(N), ACUM,  
     X EPS, PRJRES, RNORM, SAVE, DABS                                   
      INTEGER OUTPUT                                                    
      DATA OUTPUT /6/                                                   
C                                                                       
      LP1 = L + 1                                                       
      LPNL = LNL2 - 2                                                   
      LNL1 = LPNL + 1                                                   
      DO 10 I = 1, N                                                    
   10    W(I) = W(I)**2                                                 
C                                                                       
C              UNWIND HOUSEHOLDER TRANSFORMATIONS TO GET RESIDUALS,     
C              AND MOVE THE LINEAR PARAMETERS FROM R TO U.              
C                                                                       
      IF (L .EQ. 0) GO TO 30                                            
      DO 25 KBACK = 1, L                                                
         K = LP1 - KBACK                                                
         KP1 = K + 1                                                    
         ACUM = 0.                                                      
         DO 20 I = KP1, N                                               
   20       ACUM = ACUM + A(I, K) * R(I)                                
         SAVE = R(K)                                                    
         R(K) =  ACUM / A(K, K)                                         
         ACUM = -ACUM / (U(K) * A(K, K))                                
         U(K) = SAVE                                                    
         DO 25 I = KP1, N                                               
   25       R(I) = R(I) - A(I, K)*ACUM                                  
C                                              COMPUTE MEAN ERROR       
   30 ACUM = 0.                                                         
      DO 35 I = 1, N                                                    
   35    ACUM = ACUM + R(I)                                             
      SAVE = ACUM / N                                                   
C                                                                       
C              THE FIRST L COLUMNS OF THE MATRIX HAVE BEEN REDUCED TO   
C              UPPER TRIANGULAR FORM IN VPDPA.  FINISH BY REDUCING ROWS 
C              L+1 TO N AND COLUMNS L+2 THROUGH L+NL+1 TO TRIANGULAR    
C              FORM.  THEN SHIFT COLUMNS OF DERIVATIVE MATRIX OVER ONE  
C              TO THE LEFT TO BE ADJACENT TO THE FIRST L COLUMNS.       
C                                                                       
      IF (NL .EQ. 0) GO TO 45                                           
      CALL VPFAC1(NL+1, NMAX, N, L, IPRINT, A(1, L+2), PRJRES, 4)       
      DO 40 I = 1, N                                                    
         A(I, LNL2) = R(I)                                              
         DO 40 K = LP1, LNL1                                            
   40       A(I, K) = A(I, K+1)                                         
C                                              COMPUTE COVARIANCE MATRIX
   45 A(1, LNL2) = RNORM                                                
      ACUM = RNORM*RNORM/(N - L - NL)                                   
      A(2, LNL2) = ACUM                                                 
      CALL VPCOV(NMAX, LPNL, ACUM, A)                                   
C                                                                       
      IF (IPRINT .LT. 0) GO TO 99                                       
      WRITE (OUTPUT, 209)                                               
      IF (L .GT. 0) WRITE (OUTPUT, 210) (U(J), J = 1, L)                
      IF (NL .GT. 0) WRITE (OUTPUT, 211) (ALF(K), K = 1, NL)            
      WRITE (OUTPUT, 214) RNORM, SAVE, ACUM                             
      IF (DABS(SAVE) .GT. EPS) WRITE (OUTPUT, 215)                      
      WRITE (OUTPUT, 209)                                               
   99 RETURN                                                            
C                                                                       
  209 FORMAT (1H0, 50(1H'))                                             
  210 FORMAT (20H0  LINEAR PARAMETERS // (7E15.7))                      
  211 FORMAT (23H0  NONLINEAR PARAMETERS // (7E15.7))                   
  214 FORMAT (21H0  NORM OF RESIDUAL =, E15.7, 33H EXPECTED ERROR OF OBS
     XERVATIONS =, E15.7, / 39H   ESTIMATED VARIANCE OF OBSERVATIONS =, 
     X E15.7 )                                                          
  215 FORMAT (95H  WARNING -- EXPECTED ERROR OF OBSERVATIONS IS NOT ZERO
     X.  COVARIANCE MATRIX MAY BE MEANINGLESS. /)                       
      END 

CC===============================================================================                                                     
      SUBROUTINE VPCOV(NMAX, N, SIGMA2, A)                              
C                                                                       
C           COMPUTE THE SCALED COVARIANCE MATRIX OF THE L + NL          
C        PARAMETERS.  THIS INVOLVES COMPUTING                           
C                                                                       
C                               2     -1    -T                          
C                          SIGMA  *  T   * T                            
C                                                                       
C        WHERE THE (L+NL) X (L+NL) UPPER TRIANGULAR MATRIX T IS         
C        DESCRIBED IN SUBROUTINE VPPOST.  THE RESULT OVERWRITES THE     
C        FIRST L+NL ROWS AND COLUMNS OF THE MATRIX A.  THE RESULTING    
C        MATRIX IS SYMMETRIC.  SEE REF. 7, PP. 67-70, 281.              
C                                                                       
C     ..................................................................
C                                                                       
      DOUBLE PRECISION A(NMAX, N), SUM, SIGMA2                          
C                                                                       
      DO 10 J = 1, N                                                    
   10    A(J, J) = 1./A(J, J)                                           
C                                                                       
C                 INVERT T UPON ITSELF                                  
C                                                                       
      IF (N .EQ. 1) GO TO 70                                            
      NM1 = N - 1                                                       
      DO 60 I = 1, NM1                                                  
         IP1 = I + 1                                                    
         DO 60 J = IP1, N                                               
            JM1 = J - 1                                                 
            SUM = 0.                                                    
            DO 50 M = I, JM1                                            
   50          SUM = SUM + A(I, M) * A(M, J)                            
   60       A(I, J) = -SUM * A(J, J)                                    
C                                                                       
C                 NOW FORM THE MATRIX PRODUCT                           
C                                                                       
   70 DO 90 I = 1, N                                                    
         DO 90 J = I, N                                                 
            SUM = 0.                                                    
            DO 80 M = J, N                                              
   80          SUM = SUM + A(I, M) * A(J, M)                            
            SUM = SUM * SIGMA2                                          
            A(I, J) = SUM                                               
   90       A(J, I) = SUM                                               
C                                                                       
      RETURN                                                            
      END  
CCC========================================================                                                             
      SUBROUTINE VPERR (IPRINT, IERR, K)                                
C                                                                       
C        PRINT ERROR MESSAGES                                           
C                                                                       
      INTEGER ERRNO, OUTPUT                                             
      DATA OUTPUT /6/                                                   
C                                                                       
      IF (IPRINT .LT. 0) GO TO 99                                       
      ERRNO = IABS(IERR)                                                
      GO TO (1, 2, 99, 4, 5, 6, 7, 8), ERRNO                            
C                                                                       
    1 WRITE (OUTPUT, 101)                                               
      GO TO 99                                                          
    2 WRITE (OUTPUT, 102)                                               
      GO TO 99                                                          
    4 WRITE (OUTPUT, 104)                                               
      GO TO 99                                                          
    5 WRITE (OUTPUT, 105)                                               
      GO TO 99                                                          
    6 WRITE (OUTPUT, 106) K                                             
      GO TO 99                                                          
    7 WRITE (OUTPUT, 107) K                                             
      GO TO 99                                                          
    8 WRITE (OUTPUT, 108) K                                             
C                                                                       
   99 RETURN                                                            
  101 FORMAT (46H0  PROBLEM TERMINATED FOR EXCESSIVE ITERATIONS //)     
  102 FORMAT (49H0  PROBLEM TERMINATED BECAUSE OF ILL-CONDITIONING //)  
  104 FORMAT (/ 50H INPUT ERROR IN PARAMETER L, NL, N, LPP2, OR NMAX. /)
  105 FORMAT (68H0  ERROR -- INC MATRIX IMPROPERLY SPECIFIED, OR DISAGRE
     XES WITH LPP2. /)                                                  
  106 FORMAT (19H0  ERROR -- WEIGHT(, I4, 14H) IS NEGATIVE. /)          
  107 FORMAT (28H0  ERROR -- CONSTANT COLUMN , I3, 37H MUST BE COMPUTED 
     XONLY WHEN ISEL = 1.  /)                                           
  108 FORMAT (33H0  CATASTROPHIC FAILURE -- COLUMN , I4, 28H IS ZERO, SE
     XE DOCUMENTATION. /)                                               
      END             


CCC=================================================================================
                                                  
      DOUBLE PRECISION FUNCTION VPNORM(N, X)                            
C                                                                       
C        COMPUTE THE L2 (EUCLIDEAN) NORM OF A VECTOR, MAKING SURE TO    
C        AVOID UNNECESSARY UNDERFLOWS.  NO ATTEMPT IS MADE TO SUPPRESS  
C        OVERFLOWS.                                                     
C                                                                       
      DOUBLE PRECISION X(N), RMAX, SUM, TERM, DABS, DSQRT               
C                                                                       
C           FIND LARGEST (IN ABSOLUTE VALUE) ELEMENT                    
      RMAX = 0.                                                         
      DO 10 I = 1, N                                                    
         IF (DABS(X(I)) .GT. RMAX) RMAX = DABS(X(I))                    
   10    CONTINUE                                                       
C                                                                       
      SUM = 0.                                                          
      IF (RMAX .EQ. 0.) GO TO 30                                        
      DO 20 I = 1, N                                                    
         TERM = 0.                                                      
         IF (RMAX + DABS(X(I)) .NE. RMAX) TERM = X(I)/RMAX              
   20    SUM = SUM + TERM*TERM                                          
C                                                                       
   30 VPNORM = RMAX*DSQRT(SUM)                                          
   99 RETURN                                                            
      END                                                               

