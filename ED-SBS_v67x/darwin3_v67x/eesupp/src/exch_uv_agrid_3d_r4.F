#include "PACKAGES_CONFIG.h"
#include "CPP_EEOPTIONS.h"

CBOP
C     !ROUTINE: EXCH_UV_AGRID_3D_R4

C     !INTERFACE:
      SUBROUTINE EXCH_UV_AGRID_3D_R4(
     U                                uPhi, vPhi,
     I                                withSigns, myNz, myThid )

C     !DESCRIPTION:
C*=====================================================================*
C  Purpose: SUBROUTINE EXCH_UV_AGRID_3D_R4
C      handle exchanges for a 3D vector field on an A-grid.
C
C  Input:
C    uPhi(lon,lat,levs,bi,bj) :: first component of vector
C    vPhi(lon,lat,levs,bi,bj) :: second component of vector
C    withSigns (logical)      :: true to use signs of components
C    myNz                     :: 3rd dimension of input arrays uPhi,vPhi
C    myThid                   :: my Thread Id number
C
C  Output: uPhi and vPhi are updated (halo regions filled)
C
C  Calls: exch (either exch_rx_cube or exch_rx) - twice, once
C         for the first-component, once for second.
C
C  NOTES: 1) If using CubedSphereExchange, only works on ONE PROCESSOR!
C*=====================================================================*

C     !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"

C     !INPUT/OUTPUT PARAMETERS:
C     == Argument list variables ==
      INTEGER myNz
      _R4 uPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      _R4 vPhi(1-OLx:sNx+OLx,1-OLy:sNy+OLy,myNz,nSx,nSy)
      LOGICAL withSigns
      INTEGER myThid

C     !LOCAL VARIABLES:
#ifndef ALLOW_EXCH2
C     == Local variables ==
C     i,j,k,bi,bj   :: are DO indices.
C     OL[wens]      ::  Overlap extents in west, east, north, south.
C     exchWidth[XY] :: Extent of regions that will be exchanged.
C     dummy[12]     :: copies of the vector components with haloes filled.

      INTEGER i,j,k,bi,bj
      INTEGER OLw, OLe, OLn, OLs, exchWidthX, exchWidthY
      _R4 dummy1(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _R4 dummy2(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      _R4 negOne
#endif
CEOP

#ifdef ALLOW_EXCH2
      CALL EXCH2_UV_AGRID_3D_R4(
     U                           uPhi, vPhi,
     I                           withSigns, myNz, myThid )
#else /* ALLOW_EXCH2 */

      OLw        = OLx
      OLe        = OLx
      OLn        = OLy
      OLs        = OLy
      exchWidthX = OLx
      exchWidthY = OLy
      negOne = 1.
      IF (withSigns) negOne = -1.

      IF (useCubedSphereExchange) THEN
C---  using CubedSphereExchange:

C First call the exchanges for the two components

       CALL EXCH1_R4_CUBE( uPhi, .FALSE.,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH1_R4_CUBE( vPhi, .FALSE.,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )

C Then if we are on the sphere we may need to switch u and v components
C and/or the signs depending on which cube face we are located.

C--    Loops on tile and level indices:
       DO bj = myByLo(myThid), myByHi(myThid)
        DO bi = myBxLo(myThid), myBxHi(myThid)
         DO k = 1,myNz

C First we need to copy the component info into dummy arrays
          DO j = 1-OLy,sNy+OLy
           DO i = 1-OLx,sNx+OLx
             dummy1(i,j) = uPhi(i,j,k,bi,bj)
             dummy2(i,j) = vPhi(i,j,k,bi,bj)
           ENDDO
          ENDDO

C Now choose what to do at each edge of the halo based on which face
C    (we assume that bj is always=1)

C odd faces share disposition of all sections of the halo
          IF ( MOD(bi,2).EQ.1 ) THEN
           DO j = 1,sNy
            DO i = 1,exchWidthX
C east (nothing to change)
c            uPhi(sNx+i,j,k,bi,bj) = dummy1(sNx+i,j)
c            vPhi(sNx+i,j,k,bi,bj) = dummy2(sNx+i,j)
C west
             uPhi(1-i,j,k,bi,bj) = dummy2(1-i,j)
             vPhi(1-i,j,k,bi,bj) = dummy1(1-i,j)*negOne
            ENDDO
           ENDDO
           DO j = 1,exchWidthY
            DO i = 1,sNx
C north
             uPhi(i,sNy+j,k,bi,bj) = dummy2(i,sNy+j)*negOne
             vPhi(i,sNy+j,k,bi,bj) = dummy1(i,sNy+j)
C south (nothing to change)
c            uPhi(i,1-j,k,bi,bj) = dummy1(i,1-j)
c            vPhi(i,1-j,k,bi,bj) = dummy2(i,1-j)
            ENDDO
           ENDDO

          ELSE
C now the even faces (share disposition of all sections of the halo)

           DO j = 1,sNy
            DO i = 1,exchWidthX
C east
             uPhi(sNx+i,j,k,bi,bj) = dummy2(sNx+i,j)
             vPhi(sNx+i,j,k,bi,bj) = dummy1(sNx+i,j)*negOne
C west (nothing to change)
c            uPhi(1-i,j,k,bi,bj) = dummy1(1-i,j)
c            vPhi(1-i,j,k,bi,bj) = dummy2(1-i,j)
            ENDDO
           ENDDO
           DO j = 1,exchWidthY
            DO i = 1,sNx
C north (nothing to change)
c            uPhi(i,sNy+j,k,bi,bj) = dummy1(i,sNy+j)
c            vPhi(i,sNy+j,k,bi,bj) = dummy2(i,sNy+j)
C south
             uPhi(i,1-j,k,bi,bj) = dummy2(i,1-j)*negOne
             vPhi(i,1-j,k,bi,bj) = dummy1(i,1-j)

            ENDDO
           ENDDO

C end odd / even faces
          ENDIF

C--    end of Loops on tile and level indices (k,bi,bj).
         ENDDO
        ENDDO
       ENDDO

      ELSE
C---  not using CubedSphereExchange:

#ifdef DISCONNECTED_TILES
       CALL EXCH0_R4( uPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH0_R4( vPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#else /* DISCONNECTED_TILES */
       CALL EXCH1_R4( uPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
       CALL EXCH1_R4( vPhi,
     I            OLw, OLe, OLs, OLn, myNz,
     I            exchWidthX, exchWidthY,
     I            EXCH_UPDATE_CORNERS, myThid )
#endif /* DISCONNECTED_TILES */

C---  using or not using CubedSphereExchange: end
      ENDIF

#endif /* ALLOW_EXCH2 */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

CEH3 ;;; Local Variables: ***
CEH3 ;;; mode:fortran ***
CEH3 ;;; End: ***
