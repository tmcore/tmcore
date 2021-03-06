module mesh_mod

  use const_mod
  use params_mod
  use log_mod
  use io_mod

  implicit none

  ! Dimension sizes
  integer nCells
  integer nEdges
  integer nVertices
  integer vertexDegree                                    ! The maximum number of cells connected to a dual cell (or the number of corners in a dual cell)
  integer maxEdges
  integer maxEdges2
  integer, allocatable :: nEdgesOnCell(:)                 ! Number of edges on a given cell
  integer, allocatable :: nEdgesOnEdge(:)                 ! Number of edges on a given edge to reconstruct tangential velocities
  integer, allocatable :: nCellsOnVertex(:)               ! Number of cells connected with a given vertex
  ! Coordinates
  real(real_kind), allocatable :: latCell(:)
  real(real_kind), allocatable :: lonCell(:)
  real(real_kind), allocatable :: xCell(:)
  real(real_kind), allocatable :: yCell(:)
  real(real_kind), allocatable :: zCell(:)
  real(real_kind), allocatable :: latEdge(:)
  real(real_kind), allocatable :: lonEdge(:)
  real(real_kind), allocatable :: xEdge(:)
  real(real_kind), allocatable :: yEdge(:)
  real(real_kind), allocatable :: zEdge(:)
  real(real_kind), allocatable :: latVertex(:)
  real(real_kind), allocatable :: lonVertex(:)
  real(real_kind), allocatable :: xVertex(:)
  real(real_kind), allocatable :: yVertex(:)
  real(real_kind), allocatable :: zVertex(:)
  ! Geometric measures
  real(real_kind), allocatable :: dvEdge(:)                     ! Distance in meters between the vertices that saddle a given edge
  real(real_kind), allocatable :: dv1Edge(:)                    ! Distance in meters between vertex 1 and edge point
  real(real_kind), allocatable :: dv2Edge(:)                    ! Distance in meters between vertex 2 and edge point
  real(real_kind), allocatable :: dcEdge(:)                     ! Distance in meters between the cells that saddle a given edge
  real(real_kind), allocatable :: areaCell(:)                   ! Area in square meters for a given cell of the primary mesh
  real(real_kind), allocatable :: areaEdge(:)                   ! Area in square meters for a given edge point
  real(real_kind), allocatable :: areaTriangle(:)               ! Area in square meters for a given triangle of the dual mesh
  real(real_kind), allocatable :: kiteAreasOnVertex(:,:)        ! The intersection area of areaTriangle with each cell that radiates from a given vertex
  real(real_kind), allocatable :: angleEdge(:)                  ! Angle in radians an edge’s normal vector makes with the local eastward direction
  real(real_kind), allocatable :: edgeNormalVectors(:,:  )      ! The unit vector normal to the edge and tangent to the sphere
  real(real_kind), allocatable :: cellTangentPlane(:,:,:)       ! 2 orthogonal unit vectors in the tangent plane of each cell. The first unit vector is chosen to point toward the center of the first edge on the cell.
  real(real_kind), allocatable :: localVerticalUnitVectors(:,:) ! the unit normal vector of the tangent plane at the center of each cell
  
  integer, allocatable :: nSignEdge(:,:)
  integer, allocatable :: tSignEdge(:,:)
  real(real_kind) totalArea
  ! Indices
  integer, allocatable :: indexToCellID(:)                ! Global cell ID for all cell centers
  integer, allocatable :: indexToEdgeID(:)                ! Global edge ID for all edge locations
  integer, allocatable :: indexToVertexID(:)              ! Global vertex ID for all cell vertices
  integer, allocatable :: cellsOnCell(:,:)                ! Cell indices that surround a given cell
  integer, allocatable :: cellsOnEdge(:,:)                ! Cell indices that saddle a given edge
  integer, allocatable :: cellsOnVertex(:,:)              ! Cell indices that radiate from a given vertex
  integer, allocatable :: edgesOnCell(:,:)                ! Edge indices that surround a given cell
  integer, allocatable :: edgesOnEdge(:,:)                ! Edge indices that are used to reconstruct tangential velocities
  integer, allocatable :: edgesOnVertex(:,:)              ! Edge indices that radiate from a given vertex
  integer, allocatable :: verticesOnCell(:,:)             ! Vertex indices that surround a given cell
  integer, allocatable :: verticesOnEdge(:,:)             ! Vertex indices that saddle a given edge
  integer, allocatable :: verticesOnVertex(:,:)           ! Vertex indices that saddle a given vertex
  ! Weights
  real(real_kind), allocatable :: weightsOnEdge(:,:)        ! Weights to reconstruct tangential velocities
  real(real_kind), allocatable :: coeffs_reconstruct(:,:,:) ! Weights to reconstruct vector on cells
  
  real(real_kind), allocatable :: fCell(:)                ! Coriolis coefficients on a given cell
  real(real_kind), allocatable :: fVertex(:)              ! Coriolis coefficients on a given vertex
  
contains

  subroutine mesh_init()

    integer iCell, iVertex, i

    call io_create_dataset('mesh', file_path=mesh_file_path, mode='input')
    call io_get_dim('mesh', 'nCells',       size=nCells)
    call io_get_dim('mesh', 'nEdges',       size=nEdges)
    call io_get_dim('mesh', 'nVertices',    size=nVertices)
    call io_get_dim('mesh', 'vertexDegree', size=vertexDegree)
    call io_get_dim('mesh', 'maxEdges',     size=maxEdges)
    call io_get_dim('mesh', 'maxEdges2',    size=maxEdges2)

    allocate(nEdgesOnCell(nCells))
    allocate(nEdgesOnEdge(nEdges))
    allocate(latCell(nCells))
    allocate(lonCell(nCells))
    allocate(xCell(nCells))
    allocate(yCell(nCells))
    allocate(zCell(nCells))
    allocate(latEdge(nEdges))
    allocate(lonEdge(nEdges))
    allocate(xEdge(nEdges))
    allocate(yEdge(nEdges))
    allocate(zEdge(nEdges))
    allocate(latVertex(nVertices))
    allocate(lonVertex(nVertices))
    allocate(xVertex(nVertices))
    allocate(yVertex(nVertices))
    allocate(zVertex(nVertices))
    allocate(dvEdge(nEdges))
    allocate(dv1Edge(nEdges))
    allocate(dv2Edge(nEdges))
    allocate(dcEdge(nEdges))
    allocate(areaCell(nCells))
    allocate(areaTriangle(nVertices))
    allocate(kiteAreasOnVertex(vertexDegree,nVertices))
    allocate(angleEdge(nEdges))
    allocate(indexToCellID(nCells))
    allocate(indexToEdgeID(nEdges))
    allocate(indexToVertexID(nVertices))
    allocate(cellsOnCell(maxEdges,nCells))
    allocate(cellsOnEdge(2,nEdges))
    allocate(cellsOnVertex(vertexDegree,nVertices))
    allocate(edgesOnCell(maxEdges,nCells))
    allocate(edgesOnEdge(maxEdges2,nEdges))
    allocate(edgesOnVertex(vertexDegree,nVertices))
    allocate(verticesOnCell(maxEdges,nCells))
    allocate(verticesOnEdge(2,nEdges))
    allocate(verticesOnVertex(vertexDegree,nEdges))
    allocate(weightsOnEdge(maxEdges2,nEdges))
    allocate(coeffs_reconstruct(3,maxEdges,nCells))
    allocate(edgeNormalVectors(3,nEdges))
    allocate(cellTangentPlane(3,2,nCells))
    allocate(localVerticalUnitVectors(3,nCells))
    
    call io_start_input('mesh')
    call io_input('mesh', 'latCell',           latCell)
    call io_input('mesh', 'lonCell',           lonCell)
    call io_input('mesh', 'xCell',             xCell)
    call io_input('mesh', 'yCell',             yCell)
    call io_input('mesh', 'zCell',             zCell)
    call io_input('mesh', 'indexToCellID',     indexToCellID)
    call io_input('mesh', 'lonEdge',           lonEdge)
    call io_input('mesh', 'latEdge',           latEdge)
    call io_input('mesh', 'xEdge',             xEdge)
    call io_input('mesh', 'yEdge',             yEdge)
    call io_input('mesh', 'zEdge',             zEdge)
    call io_input('mesh', 'indexToEdgeID',     indexToEdgeID)
    call io_input('mesh', 'lonVertex',         lonVertex)
    call io_input('mesh', 'latVertex',         latVertex)
    call io_input('mesh', 'xVertex',           xVertex)
    call io_input('mesh', 'yVertex',           yVertex)
    call io_input('mesh', 'zVertex',           zVertex)
    call io_input('mesh', 'indexToVertexID',   indexToVertexID)
    call io_input('mesh', 'nEdgesOnCell',      nEdgesOnCell)
    call io_input('mesh', 'nEdgesOnEdge',      nEdgesOnEdge)
    call io_input('mesh', 'cellsOnCell',       cellsOnCell)
    call io_input('mesh', 'cellsOnEdge',       cellsOnEdge)
    call io_input('mesh', 'edgesOnCell',       edgesOnCell)
    call io_input('mesh', 'edgesOnEdge',       edgesOnEdge)
    call io_input('mesh', 'verticesOnCell',    verticesOnCell)
    call io_input('mesh', 'verticesOnEdge',    verticesOnEdge)
    call io_input('mesh', 'edgesOnVertex',     edgesOnVertex)
    call io_input('mesh', 'cellsOnVertex',     cellsOnVertex)
    call io_input('mesh', 'weightsOnEdge',     weightsOnEdge)
    call io_input('mesh', 'dvEdge',            dvEdge)
    call io_input('mesh', 'dv1Edge',           dv1Edge)
    call io_input('mesh', 'dv2Edge',           dv2Edge)
    call io_input('mesh', 'dcEdge',            dcEdge)
    call io_input('mesh', 'angleEdge',         angleEdge)
    call io_input('mesh', 'areaCell',          areaCell)
    call io_input('mesh', 'areaTriangle',      areaTriangle)
    call io_input('mesh', 'kiteAreasOnVertex', kiteAreasOnVertex)

    ! Derived quantities
    allocate(nCellsOnVertex(nVertices))
    allocate(areaEdge(nEdges))
    allocate(fCell(nCells))
    allocate(fVertex(nVertices))
    allocate(nSignEdge(maxEdges,nCells))
    allocate(tSignEdge(vertexDegree,nVertices))

    nCellsOnVertex = vertexDegree
    areaEdge       = dvEdge(:) * dcEdge(:)
    fCell          = 2.0d0 * omega * sin(latCell(:))
    fVertex        = 2.0d0 * omega * sin(latVertex(:))

    nSignEdge = 0
    do iCell = 1, nCells
      do i = 1, nEdgesOnCell(iCell)
        if (iCell == cellsOnEdge(1,edgesOnCell(i,iCell))) nSignEdge(i,iCell) =  1
        if (iCell == cellsOnEdge(2,edgesOnCell(i,iCell))) nSignEdge(i,iCell) = -1
      end do
    end do

    tSignEdge = 0
    do iVertex = 1, nVertices
      do i = 1, vertexDegree
        if (iVertex == verticesOnEdge(1,edgesOnVertex(i,iVertex)))then
            tSignEdge(i,iVertex) =  1
            verticesOnVertex(i,iVertex) = verticesOnEdge(2,edgesOnVertex(i,iVertex))
        end if
        
        if (iVertex == verticesOnEdge(2,edgesOnVertex(i,iVertex)))then
            tSignEdge(i,iVertex) = -1
            verticesOnVertex(i,iVertex) = verticesOnEdge(1,edgesOnVertex(i,iVertex))
        end if
      end do
    end do
    
    ! Scale mesh parameters.
    xCell             = xCell             * radius
    yCell             = yCell             * radius
    zCell             = zCell             * radius
    xEdge             = xEdge             * radius
    yEdge             = yEdge             * radius
    zEdge             = zEdge             * radius
    xVertex           = xVertex           * radius
    yVertex           = yVertex           * radius
    zVertex           = zVertex           * radius
    dvEdge            = dvEdge            * radius
    dv1Edge           = dv1Edge           * radius
    dv2Edge           = dv2Edge           * radius
    dcEdge            = dcEdge            * radius
    areaCell          = areaCell          * radius**2
    areaTriangle      = areaTriangle      * radius**2
    areaEdge          = areaEdge          * radius**2
    kiteAreasOnVertex = kiteAreasOnVertex * radius**2
    
    totalArea         = sum(areaCell)

  end subroutine mesh_init

  subroutine mesh_final()

    if (allocated(nEdgesOnCell))             deallocate(nEdgesOnCell)
    if (allocated(nEdgesOnEdge))             deallocate(nEdgesOnEdge)
    if (allocated(latCell))                  deallocate(latCell)
    if (allocated(lonCell))                  deallocate(lonCell)
    if (allocated(xCell))                    deallocate(xCell)
    if (allocated(yCell))                    deallocate(yCell)
    if (allocated(zCell))                    deallocate(zCell)
    if (allocated(latEdge))                  deallocate(latEdge)
    if (allocated(lonEdge))                  deallocate(lonEdge)
    if (allocated(xEdge))                    deallocate(xEdge)
    if (allocated(yEdge))                    deallocate(yEdge)
    if (allocated(zEdge))                    deallocate(zEdge)
    if (allocated(latVertex))                deallocate(latVertex)
    if (allocated(lonVertex))                deallocate(lonVertex)
    if (allocated(xVertex))                  deallocate(xVertex)
    if (allocated(yVertex))                  deallocate(yVertex)
    if (allocated(zVertex))                  deallocate(zVertex)
    if (allocated(dvEdge))                   deallocate(dvEdge)
    if (allocated(dcEdge))                   deallocate(dcEdge)
    if (allocated(areaCell))                 deallocate(areaCell)
    if (allocated(areaTriangle))             deallocate(areaTriangle)
    if (allocated(kiteAreasOnVertex))        deallocate(kiteAreasOnVertex)
    if (allocated(angleEdge))                deallocate(angleEdge)
    if (allocated(indexToCellID))            deallocate(indexToCellID)
    if (allocated(indexToEdgeID))            deallocate(indexToEdgeID)
    if (allocated(indexToVertexID))          deallocate(indexToVertexID)
    if (allocated(cellsOnCell))              deallocate(cellsOnCell)
    if (allocated(cellsOnEdge))              deallocate(cellsOnEdge)
    if (allocated(cellsOnVertex))            deallocate(cellsOnVertex)
    if (allocated(edgesOnCell))              deallocate(edgesOnCell)
    if (allocated(edgesOnEdge))              deallocate(edgesOnEdge)
    if (allocated(edgesOnVertex))            deallocate(edgesOnVertex)
    if (allocated(verticesOnCell))           deallocate(verticesOnCell)
    if (allocated(verticesOnEdge))           deallocate(verticesOnEdge)
    if (allocated(weightsOnEdge))            deallocate(weightsOnEdge)
    if (allocated(nCellsOnVertex))           deallocate(nCellsOnVertex)
    if (allocated(areaEdge))                 deallocate(areaEdge)
    if (allocated(fCell))                    deallocate(fCell)
    if (allocated(fVertex))                  deallocate(fVertex)
    if (allocated(nSignEdge))                deallocate(nSignEdge)
    if (allocated(tSignEdge))                deallocate(tSignEdge)
    if (allocated(edgeNormalVectors))        deallocate(edgeNormalVectors)
    if (allocated(cellTangentPlane))         deallocate(cellTangentPlane)
    if (allocated(localVerticalUnitVectors)) deallocate(localVerticalUnitVectors)
    
  end subroutine mesh_final

end module mesh_mod
