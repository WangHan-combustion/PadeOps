subroutine DoStandardDynamicProcedure(this, u, v, w, Sij)
   class(sgs_igrid), intent(inout), target :: this
   real(rkind), dimension(this%gpC%xsz(1),this%gpC%xsz(2),this%gpC%xsz(3)),   intent(in) :: u, v, w
   real(rkind), dimension(this%gpC%xsz(1),this%gpC%xsz(2),this%gpC%xsz(3),6), intent(in) :: Sij
   
   real(rkind), dimension(:,:,:), pointer :: Sij_filt, numerator, denominator

   ! What has already been computed?  
   !     a) Sij has been computed (and passed in as argument)
   !     b) SGS eddy viscosity kernel, Dsgs and stored in this%Dsgs
   !     c) DeltaRatio has been set in the variable this%DeltaRat
   !     d) SGS kernel at grid scale, accessed as this%nu_sgs_C

   ! What memory can I use? (arrays of size of u, v, w)
   !     a) numerator : real valued buffer (same size as u, v, w) (will get destroyed after exiting)
   !     b) denominator : real valued buffer (same size as u, v, w) (will get destroyed after exiting)
   !     c) Sij_filt : real valued storage for filtered Sij (same size as Sij) (will get destroyed after exiting)
   !     d) this%Dsgs_filt: real valued storage for Dsgs computed from filterd Sij

   ! What happens during the SETUP portion of this routine? 
   !     a) Pointers are set appropriately to get access to the required memory

   ! What happens during the CORE portion of this routine? 
   !     a) Compute MijMij and LijMij

   ! What happens in the WRAPUP portion of this routine? 
   !     a) numerator and denominator are averaged in x, y planes
   !     b) averaged values of numerator and denominator are divided and stored in this%LambdaDynProc_C
   !     b) this%LambdaDynProc_C is interpolated to LambdaDynProc_E (from cells to edges)
   !     c) All local pointers are nullified

   ! What happens after this subroutine? 
   !     a) this%LambdaDynProc_C is multiplied to SGS model kernel this%nu_sgs_C
   !     b) SGS stress is computed as tau_ij = -2*this%nu_sgs_C*Sij
   !     c) Wall model (if being used), is embedded in tau_ij
   !     d) Divergence of tau_ij is computed and added to momentum RHS

   ! Does this routine have any side-effects? YES! this%tau_ij values set
   ! previously are ruined. 

   ! =========================== SETUP =================================
   Sij_filt => this%tau_ij
   numerator   => this%rbuffxC(:,:,:,1)
   denominator => this%rbuffxC(:,:,:,2)

   ! =========================== CORE  =================================



   ! =========================  WRAPUP  ================================

end subroutine 


















subroutine DoStandardDynamicProcedure(this, uE, vE, wE, uhatE, vhatE, whatE, duidxjEhat)
   class(sgs_igrid), intent(inout) :: this
   real(rkind), dimension(this%gpE%xsz(1),this%gpE%xsz(2),this%gpE%xsz(3)), intent(in) :: uE, vE, wE
   complex(rkind), dimension(this%sp_gpE%ysz(1),this%sp_gpE%ysz(2),this%sp_gpE%ysz(3))  , intent(in) :: uhatE, vhatE, whatE
   complex(rkind), dimension(this%sp_gpE%ysz(1),this%sp_gpE%ysz(2),this%sp_gpE%ysz(3),9), intent(in) :: duidxjEhat
   integer :: idx
   
   ! STEP 1: Test filter velocities (required for Lij)
   call this%TestFilter_Cmplx_to_Real(uhatE, this%ui_Filt(:,:,:,1))   
   call this%TestFilter_Cmplx_to_Real(vhatE, this%ui_Filt(:,:,:,2))   
   call this%TestFilter_Cmplx_to_Real(whatE, this%ui_Filt(:,:,:,3))   

   ! STEP 2: Compute Lij
   this%buff1 = uE*uE
   call this%TestFilter_real_to_real(this%buff1, this%buff2)
   this%Lij(:,:,:,1) = -this%buff2 + this%ui_Filt(:,:,:,1)*this%ui_Filt(:,:,:,1)
   
   this%buff1 = uE*vE
   call this%TestFilter_real_to_real(this%buff1, this%buff2)
   this%Lij(:,:,:,2) = -this%buff2 + this%ui_Filt(:,:,:,1)*this%ui_Filt(:,:,:,2)

   this%buff1 = uE*wE
   call this%TestFilter_real_to_real(this%buff1, this%buff2)
   this%Lij(:,:,:,3) = -this%buff2 + this%ui_Filt(:,:,:,1)*this%ui_Filt(:,:,:,3)
   
   this%buff1 = vE*vE
   call this%TestFilter_real_to_real(this%buff1, this%buff2)
   this%Lij(:,:,:,4) = -this%buff2 + this%ui_Filt(:,:,:,2)*this%ui_Filt(:,:,:,2)
   
   this%buff1 = vE*wE
   call this%TestFilter_real_to_real(this%buff1, this%buff2)
   this%Lij(:,:,:,5) = -this%buff2 + this%ui_Filt(:,:,:,2)*this%ui_Filt(:,:,:,3)

   this%buff1 = wE*wE
   call this%TestFilter_real_to_real(this%buff1, this%buff2)
   this%Lij(:,:,:,6) = -this%buff2 + this%ui_Filt(:,:,:,3)*this%ui_Filt(:,:,:,3)

   
   ! STEP 3: Compute M_ij
   ! Part a: Compute \tilde{duidxj}
   do idx = 1,9
      call this%TestFilter_cmplx_to_real(duidxjEhat(:,:,:,idx),this%alphaij_Filt(:,:,:,idx))
   end do
   ! Part b: Compute \tilde{Sij}, NOTE: Mij is used to store filtered Sij
   call get_Sij_from_duidxj(this%alphaij_Filt, this%Mij, size(this%Mij,1), size(this%Mij,2), size(this%Mij,3))
   ! Part c: Compute \tilde{D_SGS}
   select case (this%mid)
   case (0) ! smagorinsky
      call get_smagorinsky_kernel(this%Mij,this%Dsgs_filt, &
                              this%gpE%xsz(1),this%gpE%xsz(2),this%gpE%xsz(3))
   case (1) ! sigma
      call get_sigma_kernel(this%Dsgs_filt, this%alphaij_Filt, &
                              this%gpE%xsz(1),this%gpE%xsz(2),this%gpE%xsz(3))
   end select
   ! Part d: Compute the rest of it
   do idx = 1,6
      this%buff1 = this%Dsgs*this%S_ij_E(:,:,:,idx)
      call this%TestFilter_real_to_real(this%buff1,this%buff2)
      this%buff1 = (this%deltaRat*this%deltaRat)*this%Dsgs_filt*this%Mij(:,:,:,idx)
      this%Mij(:,:,:,idx) = this%buff1 - this%buff2
   end do 


   ! STEP 4: Compute the numerator
   this%buff1 = this%Lij(:,:,:,1)*this%Mij(:,:,:,1)
   do idx = 2,6
      this%buff1 = this%buff1 + this%Lij(:,:,:,idx)*this%Mij(:,:,:,idx)
   end do 

   ! STEP 5: Compute the denominator
   this%buff2 = this%Mij(:,:,:,1)*this%Mij(:,:,:,1)
   do idx = 2,6
      this%buff2 = this%buff2 + this%Mij(:,:,:,idx)*this%Mij(:,:,:,idx)
   end do
   this%buff2 = 2.d0 * this%buff2

   ! STEP 6: Get the planar average and interpolate
   !call this%planarAverage(this%buff1)
   !call this%planarAverage(this%buff2)
   call this%planarAverageAndInterpolateToCells(this%buff1, this%buff2, this%rbuffxC(:,:,:,1))
   this%cmodelE = this%buff1(1,1,:)
   this%cmodelC = this%rbuffxC(1,1,:,1)
end subroutine


subroutine planarAverageAndInterpolateToCells(this, numE, denE, ratC)
   class(sgs_igrid), intent(inout) :: this
   real(rkind), dimension(this%gpE%xsz(1), this%gpE%xsz(2), this%gpE%xsz(3)), intent(inout) :: numE
   real(rkind), dimension(this%gpE%xsz(1), this%gpE%xsz(2), this%gpE%xsz(3)), intent(in)    :: denE
   real(rkind), dimension(this%gpE%xsz(1), this%gpE%xsz(2), this%gpE%xsz(3)), intent(out)   :: ratC
   integer :: idx
   
   call transpose_x_to_y(numE, this%rbuffyE(:,:,:,1), this%gpE)
   call transpose_y_to_z(this%rbuffyE(:,:,:,1), this%rbuffzE(:,:,:,1), this%gpE)
   do idx = 1,this%gpE%zsz(3)
      this%rbuffzE(:,:,idx,1) = max(p_sum(sum(this%rbuffzE(:,:,idx,1)))*this%meanfact, zero)
   end do 
   
   call transpose_x_to_y(denE, this%rbuffyE(:,:,:,1), this%gpE)
   call transpose_y_to_z(this%rbuffyE(:,:,:,1), this%rbuffzE(:,:,:,2), this%gpE)
   do idx = 1,this%gpE%zsz(3)
      this%rbuffzE(:,:,idx,2) = p_sum(sum(this%rbuffzE(:,:,idx,2)))*this%meanfact
   end do
   this%rbuffzE(:,:,:,1) = this%rbuffzE(:,:,:,1)/(this%rbuffzE(:,:,:,2) + 1.d-14)
   this%cmodel_allZ = this%rbuffzE(1,1,:,1)

   this%rbuffzC(:,:,1:this%gpC%zsz(3),1) = 0.5d0*(this%rbuffzE(:,:,1:this%gpC%zsz(3),1)+this%rbuffzE(:,:,2:this%gpC%zsz(3)+1,1))
   call transpose_z_to_y(this%rbuffzE(:,:,:,1), this%rbuffyE(:,:,:,1), this%gpE)
   call transpose_y_to_x(this%rbuffyE(:,:,:,1), numE, this%gpE)

   call transpose_z_to_y(this%rbuffzC(:,:,:,1), this%rbuffyC(:,:,:,1), this%gpC)
   call transpose_y_to_x(this%rbuffyC(:,:,:,1), ratC, this%gpE)
end subroutine


