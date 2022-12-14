#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP
C     !ROUTINE: EXCH2_UV_BGRID_3D_R8

C     !INTERFACE:
      SUBROUTINE EXCH2_UV_BGRID_3D_R8(
     U                                 uPhi, vPhi,
     I                                 withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH2_UV_BGRID_3D_R8
C      handle exchanges for a 3D vector field on a B-grid.
C
C  Input:
C    uPhi(lon,lat,levs,bi,bj) :: first component of vector
C    vPhi(lon,lat,levs,bi,bj) :: second component of vector
C    withSigns (logical)      :: true to use sign of components
C    myNz                     :: 3rd dimension of input arrays uPhi,vPhi
C    myThid                   :: my Thread Id number
C
C  Output: uPhi and vPhi are updated (halo regions filled)
C
C  Calls: exch_R8 (exch2_R81_cube) - for each component
C
C*=====================================================================*

C     !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "W2_EXCH2_SIZE.h"
#include "W2_EXCH2_TOPOLOGY.h"
c#ifdef W2_FILL_NULL_REGIONS
c#include "W2_EXCH2_PARAMS.h"
c#endif

C     !INPUT/OUTPUT PARAMETERS:
C     == Argument list variables ==
      INTEGER myNz
      _R8 uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _R8 vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     local_maxDim  :: upper limit of 3rd dimension value
C     i,j,k,bi,bj   :: loop indices.
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.
C     uPhiNW,uPhiSE :: temporary array to hold corner value (CS grid)
C     vPhiNW,vPhiSE :: temporary array to hold corner value (CS grid)
C     uLoc,vLoc     :: local copy of the vector components with haloes filled.
C     msgBuf        :: Informational/error message buffer

      INTEGER local_maxDim
      PARAMETER( local_maxDim = 8*Nr )
      INTEGER i,j,k,bi,bj
      INTEGER myTile, myFace
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _R8 uPhiNW(local_maxDim,nSx,nSy), uPhiSE(local_maxDim,nSx,nSy)
      _R8 vPhiNW(local_maxDim,nSx,nSy), vPhiSE(local_maxDim,nSx,nSy)
      _R8 uLoc(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _R8 vLoc(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _R8 negOne
      CHARACTER*(MAX_LEN_MBUF) msgBuf

CEOP

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      negOne = 1.
      IF (withSigns) negOne = -1.

      IF ( useCubedSphereExchange ) THEN
C---  using CubedSphereExchange:
       IF ( myNz.GT.local_maxDim ) THEN
         WRITE(msgBuf,'(2A,2(I4,A))') 'EXCH2_UV_BGRID_3D_R8 :',
     &     ' 3rd dimension=', myNz,
     &     ' exceeds local_maxDim (=', local_maxDim, ' )'
         CALL PRINT_ERROR( msgBuf , myThid )
         WRITE(msgBuf,'(2A)') 'EXCH2_UV_BGRID_3D_R8 :',
     &     ' Increase "local_maxDim" and recompile'
         CALL PRINT_ERROR( msgBuf , myThid )
         STOP 'ABNORMAL END: S/R EXCH2_UV_BGRID_3D_R8'
       ENDIF

C-     save 2 corners value (in case we find 1 "missing corner")
       DO bj=myByLo(myThid),myByHi(myThid)
        DO bi=myBxLo(myThid),myBxHi(myThid)
         DO k=1,myNz
          uPhiNW(k,bi,bj) = uPhi(1,sNy+1,k,bi,bj)
          vPhiNW(k,bi,bj) = vPhi(1,sNy+1,k,bi,bj)
          uPhiSE(k,bi,bj) = uPhi(sNx+1,1,k,bi,bj)
          vPhiSE(k,bi,bj) = vPhi(sNx+1,1,k,bi,bj)
         ENDDO
        ENDDO
       ENDDO
C---  using or not using CubedSphereExchange: end
      ENDIF

C--   First call the exchanges for the two components

       CALL EXCH2_R81_CUBE( uPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_R81_CUBE( uPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

       CALL EXCH2_R81_CUBE( vPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_R81_CUBE( vPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

C- note: can substitute the low-level S/R calls above with:
c      CALL EXCH2_3D_R8( uPhi, myNz, myThid )
c      CALL EXCH2_3D_R8( vPhi, myNz, myThid )

      IF ( useCubedSphereExchange ) THEN

C--   Then, depending on which tile we are, we may need
C     1) to switch u and v components and also to switch the signs
C     2) to shift the index along the face edge.
C     3) ensure that near-corner halo regions is filled in the correct order
C      (i.e. with velocity component already available after 1 exch)
C-    note: because of index shift, the order really matter:
C           odd faces,  do North 1rst and then West;
C           even faces, do East 1rst and then South.

C--   Loops on tile indices:
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)

C-    Choose what to do at each edge of the halo based on which face we are
         myTile = W2_myTileList(bi,bj)
         myFace = exch2_myFace(myTile)

C--   Loops on level index:
         DO k = 1,myNz

C-    First we copy the 2 components info into local dummy arrays uLoc,vLoc
          DO j = 1-OLy,sNy+OLy
           DO i = 1-OLx,sNx+OLx
             uLoc(i,j) = uPhi(i,j,k,bi,bj)
             vLoc(i,j) = vPhi(i,j,k,bi,bj)
           ENDDO
          ENDDO

C-    odd faces share disposition of all sections of the halo
          IF ( MOD(myFace,2).EQ.1 ) THEN
C-    North:
           IF (exch2_isNedge(myTile).EQ.1) THEN
C      switch u <- v , reverse the sign & shift i+1 <- i
C      switch v <- u , keep the sign & shift i+1 <- i
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx-1
               uPhi(i+1,sNy+j,k,bi,bj) = vLoc(i,sNy+j)*negOne
               vPhi(i+1,sNy+j,k,bi,bj) = uLoc(i,sNy+j)
              ENDDO
             ENDDO
           ENDIF
C-    South (nothing to change)
c          IF (exch2_isSedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,1-j,k,bi,bj) = uLoc(i,1-j)
c              vPhi(i,1-j,k,bi,bj) = vLoc(i,1-j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    East (nothing to change)
c          IF (exch2_isEedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(sNx+i,j,k,bi,bj) = uLoc(sNx+i,j)
c              vPhi(sNx+i,j,k,bi,bj) = vLoc(sNx+i,j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    West:
           IF (exch2_isWedge(myTile).EQ.1) THEN
C      switch u <- v , keep the sign & shift j+1 <- j
C      switch v <- u , reverse the sign & shift j+1 <- j
             DO j = 1-OLy,sNy+OLy-1
              DO i = 1,exchWidthX
               uPhi(1-i,j+1,k,bi,bj) = vLoc(1-i,j)
               vPhi(1-i,j+1,k,bi,bj) = uLoc(1-i,j)*negOne
              ENDDO
             ENDDO
           ENDIF

          ELSE
C-    Now the even faces (share disposition of all sections of the halo)

C-    East:
           IF (exch2_isEedge(myTile).EQ.1) THEN
C      switch u <- v , keep the sign & shift j+1 <- j
C      switch v <- u , reverse the sign & shift j+1 <- j
             DO j = 1-OLy,sNy+OLy-1
              DO i = 1,exchWidthX
               uPhi(sNx+i,j+1,k,bi,bj) = vLoc(sNx+i,j)
               vPhi(sNx+i,j+1,k,bi,bj) = uLoc(sNx+i,j)*negOne
              ENDDO
             ENDDO
           ENDIF
C-    West (nothing to change)
c          IF (exch2_isWedge(myTile).EQ.1) THEN
c            DO j = 1-OLy,sNy+OLy
c             DO i = 1,exchWidthX
c              uPhi(1-i,j,k,bi,bj) = uLoc(1-i,j)
c              vPhi(1-i,j,k,bi,bj) = vLoc(1-i,j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    North (nothing to change)
c          IF (exch2_isNedge(myTile).EQ.1) THEN
c            DO j = 1,exchWidthY
c             DO i = 1-OLx,sNx+OLx
c              uPhi(i,sNy+j,k,bi,bj) = uLoc(i,sNy+j)
c              vPhi(i,sNy+j,k,bi,bj) = vLoc(i,sNy+j)
c             ENDDO
c            ENDDO
c          ENDIF
C-    South:
           IF (exch2_isSedge(myTile).EQ.1) THEN
C      switch u <- v , reverse the sign & shift i+1 <- i
C      switch v <- u , keep the sign & shift i+1 <- i
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx-1
               uPhi(i+1,1-j,k,bi,bj) = vLoc(i,1-j)*negOne
               vPhi(i+1,1-j,k,bi,bj) = uLoc(i,1-j)
              ENDDO
             ENDDO
           ENDIF

C-    end odd / even faces
          ENDIF

C--   end of Loops on level index k.
         ENDDO

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
C--   Now fix edges near cube-corner

C-       South-West corner
         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            DO i=1,OLx
             vPhi(1-i,1,k,bi,bj) = uPhi(1,1-i,k,bi,bj)*negOne
             uPhi(1-i,1,k,bi,bj) = vPhi(1,1-i,k,bi,bj)
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            DO i=1,OLx
             uPhi(1,1-i,k,bi,bj) = vPhi(1-i,1,k,bi,bj)*negOne
             vPhi(1,1-i,k,bi,bj) = uPhi(1-i,1,k,bi,bj)
            ENDDO
           ENDDO
          ENDIF
         ENDIF

C-       South-East corner
         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            DO i=2,OLx
             uPhi(sNx+1,2-i,k,bi,bj) = vPhi(sNx+i,1,k,bi,bj)
             vPhi(sNx+1,2-i,k,bi,bj) = uPhi(sNx+i,1,k,bi,bj)*negOne
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            uPhi(sNx+1,1,k,bi,bj) = uPhiSE(k,bi,bj)
            vPhi(sNx+1,1,k,bi,bj) = vPhiSE(k,bi,bj)
            DO i=2,OLx
             uPhi(sNx+i,1,k,bi,bj) = vPhi(sNx+1,2-i,k,bi,bj)*negOne
             vPhi(sNx+i,1,k,bi,bj) = uPhi(sNx+1,2-i,k,bi,bj)
            ENDDO
           ENDDO
          ENDIF
         ENDIF

C-       North-East corner
         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            DO i=2,OLx
             uPhi(sNx+i,sNy+1,k,bi,bj)=vPhi(sNx+1,sNy+i,k,bi,bj)
             vPhi(sNx+i,sNy+1,k,bi,bj)=uPhi(sNx+1,sNy+i,k,bi,bj)*negOne
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            DO i=2,OLx
             uPhi(sNx+1,sNy+i,k,bi,bj)=vPhi(sNx+i,sNy+1,k,bi,bj)*negOne
             vPhi(sNx+1,sNy+i,k,bi,bj)=uPhi(sNx+i,sNy+1,k,bi,bj)
            ENDDO
           ENDDO
          ENDIF
         ENDIF

C-       North-West corner
         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            uPhi(1,sNy+1,k,bi,bj) = uPhiNW(k,bi,bj)
            vPhi(1,sNy+1,k,bi,bj) = vPhiNW(k,bi,bj)
            DO i=2,OLx
             uPhi(1,sNy+i,k,bi,bj) = vPhi(2-i,sNy+1,k,bi,bj)
             vPhi(1,sNy+i,k,bi,bj) = uPhi(2-i,sNy+1,k,bi,bj)*negOne
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            DO i=2,OLx
             uPhi(2-i,sNy+1,k,bi,bj) = vPhi(1,sNy+i,k,bi,bj)*negOne
             vPhi(2-i,sNy+1,k,bi,bj) = uPhi(1,sNy+i,k,bi,bj)
            ENDDO
           ENDDO
          ENDIF
         ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

#ifdef W2_FILL_NULL_REGIONS
C--   Now zero out the null areas that should not be used in the numerics

         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
C     Zero SW corner points
          DO k=1,myNz
           DO j=1-OLy,0
            DO i=1-OLx,0
             uPhi(i,j,k,bi,bj)=e2FillValue_R8
             vPhi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF

         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
C     Zero NW corner points
          DO k=1,myNz
           DO j=sNy+2,sNy+OLy
            DO i=1-OLx,0
             uPhi(i,j,k,bi,bj)=e2FillValue_R8
             vPhi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF

         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
C     Zero SE corner points
          DO k=1,myNz
           DO j=1-OLy,0
            DO i=sNx+2,sNx+OLx
             uPhi(i,j,k,bi,bj)=e2FillValue_R8
             vPhi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF

         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
C     Zero NE corner points
          DO k=1,myNz
           DO j=sNy+2,sNy+OLy
            DO i=sNx+2,sNx+OLx
             uPhi(i,j,k,bi,bj)=e2FillValue_R8
             vPhi(i,j,k,bi,bj)=e2FillValue_R8
            ENDDO
           ENDDO
          ENDDO
         ENDIF

#endif /* W2_FILL_NULL_REGIONS */

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   end of Loops on tile indices (bi,bj).
        ENDDO
       ENDDO

C---  using or not using CubedSphereExchange: end
      ENDIF

      RETURN
      END

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
