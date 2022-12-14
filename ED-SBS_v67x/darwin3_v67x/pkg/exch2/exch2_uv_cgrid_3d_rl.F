#include "CPP_EEOPTIONS.h"
#include "W2_OPTIONS.h"

CBOP
C     !ROUTINE: EXCH2_UV_CGRID_3D_RL

C     !INTERFACE:
      SUBROUTINE EXCH2_UV_CGRID_3D_RL(
     U                                 uPhi, vPhi,
     I                                 withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH2_UV_CGRID_3D_RL
C      handle exchanges for a 3D vector field on a C-grid.
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
C  Calls: exch_RL (exch2_RL1_cube) - for each component
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
      _RL uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _RL vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
C     == Local variables ==
C     i,j,k,bi,bj   :: loop indices.
C     OL[wens]      :: Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.
C     uLoc,vLoc     :: local copy of the vector components with haloes filled.

      INTEGER i,j,k,bi,bj
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _RL uLoc(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL vLoc(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _RL negOne
      INTEGER myTile, myFace
CEOP

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      negOne = 1.
      IF (withSigns) negOne = -1.

C--   First call the exchanges for the two components

       CALL EXCH2_RL1_CUBE( uPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_RL1_CUBE( uPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

       CALL EXCH2_RL1_CUBE( vPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_IGNORE_CORNERS, myThid )
       CALL EXCH2_RL1_CUBE( vPhi, .FALSE., 'T ',
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

C- note: can substitute the low-level S/R calls above with:
c      CALL EXCH2_3D_RL( uPhi, myNz, myThid )
c      CALL EXCH2_3D_RL( vPhi, myNz, myThid )

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
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx-1
               uPhi(i+1,sNy+j,k,bi,bj) = vLoc(i,sNy+j)*negOne
              ENDDO
             ENDDO
C      switch v <- u , keep the sign
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               vPhi(i,sNy+j,k,bi,bj) = uLoc(i,sNy+j)
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
C      switch u <- v , keep the sign
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
               uPhi(1-i,j,k,bi,bj) = vLoc(1-i,j)
              ENDDO
             ENDDO
C      switch v <- u , reverse the sign & shift j+1 <- j
             DO j = 1-OLy,sNy+OLy-1
              DO i = 1,exchWidthX
               vPhi(1-i,j+1,k,bi,bj) = uLoc(1-i,j)*negOne
              ENDDO
             ENDDO
           ENDIF

          ELSE
C-    Now the even faces (share disposition of all sections of the halo)

C-    East:
           IF (exch2_isEedge(myTile).EQ.1) THEN
C      switch u <- v , keep the sign
             DO j = 1-OLy,sNy+OLy
              DO i = 1,exchWidthX
               uPhi(sNx+i,j,k,bi,bj) = vLoc(sNx+i,j)
              ENDDO
             ENDDO
C      switch v <- u , reverse the sign & shift j+1 <- j
             DO j = 1-OLy,sNy+OLy-1
              DO i = 1,exchWidthX
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
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx-1
               uPhi(i+1,1-j,k,bi,bj) = vLoc(i,1-j)*negOne
              ENDDO
             ENDDO
C      switch v <- u , keep the sign
             DO j = 1,exchWidthY
              DO i = 1-OLx,sNx+OLx
               vPhi(i,1-j,k,bi,bj) = uLoc(i,1-j)
              ENDDO
             ENDDO
           ENDIF

C-    end odd / even faces
          ENDIF

C--   end of Loops on level index k.
         ENDDO

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
C--   Now fix edges near cube-corner

         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            DO i=1,OLx
             vPhi(1-i,1,k,bi,bj) = uPhi(1,1-i,k,bi,bj)*negOne
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            DO i=1,OLx
             uPhi(1,1-i,k,bi,bj) = vPhi(1-i,1,k,bi,bj)*negOne
            ENDDO
           ENDDO
          ENDIF
         ENDIF

         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            DO i=1,OLx
             uPhi(sNx+1,1-i,k,bi,bj) = vPhi(sNx+i,1,k,bi,bj)
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            DO i=1,OLx
             vPhi(sNx+i,1,k,bi,bj) = uPhi(sNx+1,1-i,k,bi,bj)
            ENDDO
           ENDDO
          ENDIF
         ENDIF

         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            DO i=1,OLx
             vPhi(sNx+i,sNy+1,k,bi,bj)=uPhi(sNx+1,sNy+i,k,bi,bj)*negOne
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            DO i=1,OLx
             uPhi(sNx+1,sNy+i,k,bi,bj)=vPhi(sNx+i,sNy+1,k,bi,bj)*negOne
            ENDDO
           ENDDO
          ENDIF
         ENDIF

         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
          IF ( MOD(myFace,2).EQ.1 ) THEN
           DO k=1,myNz
            DO i=1,OLx
             uPhi(1,sNy+i,k,bi,bj) = vPhi(1-i,sNy+1,k,bi,bj)
            ENDDO
           ENDDO
          ELSE
           DO k=1,myNz
            DO i=1,OLx
             vPhi(1-i,sNy+1,k,bi,bj) = uPhi(1,sNy+i,k,bi,bj)
            ENDDO
           ENDDO
          ENDIF
         ENDIF

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   Now zero out the null areas that should not be used in the numerics
C     Also add one valid u,v value next to the corner, that allows
C     to compute vorticity on a wider stencil (e.g., vort3(0,1) & (1,0))

         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
C     Zero SW corner points
          DO k=1,myNz
#ifdef W2_FILL_NULL_REGIONS
           DO j=1-OLy,0
            DO i=1-OLx,0
             uPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
           DO j=1-OLy,0
            DO i=1-OLx,0
             vPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
#endif
           uPhi(0,0,k,bi,bj)=vPhi(1,0,k,bi,bj)
           vPhi(0,0,k,bi,bj)=uPhi(0,1,k,bi,bj)
          ENDDO
         ENDIF

         IF ( exch2_isWedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
C     Zero NW corner points
          DO k=1,myNz
#ifdef W2_FILL_NULL_REGIONS
           DO j=sNy+1,sNy+OLy
            DO i=1-OLx,0
             uPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
           DO j=sNy+2,sNy+OLy
            DO i=1-OLx,0
             vPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
#endif
           uPhi(0,sNy+1,k,bi,bj)= vPhi(1,sNy+2,k,bi,bj)*negOne
           vPhi(0,sNy+2,k,bi,bj)= uPhi(0,sNy,k,bi,bj)*negOne
          ENDDO
         ENDIF

         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isSedge(myTile) .EQ. 1 ) THEN
C     Zero SE corner points
          DO k=1,myNz
#ifdef W2_FILL_NULL_REGIONS
           DO j=1-OLy,0
            DO i=sNx+2,sNx+OLx
             uPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
           DO j=1-OLy,0
            DO i=sNx+1,sNx+OLx
             vPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
#endif
           uPhi(sNx+2,0,k,bi,bj)= vPhi(sNx,0,k,bi,bj)*negOne
           vPhi(sNx+1,0,k,bi,bj)= uPhi(sNx+2,1,k,bi,bj)*negOne
          ENDDO
         ENDIF

         IF ( exch2_isEedge(myTile) .EQ. 1 .AND.
     &        exch2_isNedge(myTile) .EQ. 1 ) THEN
C     Zero NE corner points
          DO k=1,myNz
#ifdef W2_FILL_NULL_REGIONS
           DO j=sNy+1,sNy+OLy
            DO i=sNx+2,sNx+OLx
             uPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
           DO j=sNy+2,sNy+OLy
            DO i=sNx+1,sNx+OLx
             vPhi(i,j,k,bi,bj)=e2FillValue_RL
            ENDDO
           ENDDO
#endif
           uPhi(sNx+2,sNy+1,k,bi,bj)=vPhi(sNx,sNy+2,k,bi,bj)
           vPhi(sNx+1,sNy+2,k,bi,bj)=uPhi(sNx+2,sNy,k,bi,bj)
          ENDDO
         ENDIF
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
