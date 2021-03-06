//################################################################################
//#
//# Author: Praveen Baburao Kulkarni praveen@spikingneurons.com
//#
//################################################################################
//#
//# 
//#
//################################################################################


#include "MD_define_v7_0.h"

#if PROFILING

double* acc;
double* box;
double* force;
double* pos;
double* vel;

void initialize();




int main(int argc, char** argv) {

    np = ENTERED_NP;
    BLOCK_SIZE = ENTERED_BLOCKSIZE;
    
	double rmass = 1.0/mass; 

    printf("\n\n\n|||||||||||||||||||||| USE THIS FOR PROFILER ONLY ||||||||||||||||||||||||||||\n\n\n");
    
    acc = (double*) malloc(nd * np * sizeof (double));
    box = (double*) malloc(nd * sizeof (double));
    force = (double*) malloc(nd * np * sizeof (double));
    pos = (double*) malloc(nd * np * sizeof (double));
	vel = (double*) malloc(nd * np * sizeof (double));
	double* parpot = (double*) malloc(np * sizeof (double));
    double* parforce = (double*) malloc(nd * np * sizeof (double));
    double* velnew = (double*) malloc(nd * np * sizeof (double));
	double* accnew = (double*) malloc(nd * np * sizeof (double));
  
    
	// initialize the arrays with some values
	initialize();
	allocateArrayOnGPU_acc(nd * np);
	allocateArrayOnGPU_force(nd * np);
	allocateArrayOnGPU_vel(nd * np);
	allocateArrayOnGPU_pos(nd * np);
	allocateArrayOnGPU_parpot(np);
	allocateArrayOnGPU_parforce(nd * np);   
    allocateArrayOnGPU_velnew(nd * np); 
    allocateArrayOnGPU_accnew(nd * np);
    copyArrayOnGPU_acc(acc, nd * np);
	copyArrayOnGPU_force(force, nd * np);
	copyArrayOnGPU_parforce(parforce, nd * np);
	copyArrayOnGPU_pos(pos, nd * np);
	copyArrayOnGPU_parpot(parpot, np);
	copyArrayOnGPU_vel(vel, nd * np);
	copyArrayOnGPU_velnew(velnew, nd * np);
	copyArrayOnGPU_accnew(accnew, nd * np);
	
	

	// [K1] kernel 1 : cuda_compute_forceonparticle(nd, np, 1, PI2);
    cuda_compute_forceonparticle(nd, np, 1, PI2);

	// [K2sh] kernel 2 with shared memory : cuda_cumulate_parpot_withsharedmemory(nd,np);
    cuda_cumulate_parpot_withsharedmemory(nd,np);
    
	// [K2nsh] kernel 2 without shared memory : cuda_cumulate_parpot_withoutsharedmemory(nd,np);
    cuda_cumulate_parpot_withoutsharedmemory(nd,np);

	// [K3sh] kernel 3  with shared memory : cuda_cumulate_parforce_withsharedmemory(nd,np,1);
	cuda_cumulate_parforce_withsharedmemory(nd,np,1);
	
	// [K3nsh] kernel 3  without shared memory : cuda_cumulate_parforce_withoutsharedmemory(nd,np,1);
	cuda_cumulate_parforce_withoutsharedmemory(nd,np,1);
	
	// [K4sh] kernel 4 with shared memory : cuda_compute_kineticenergy_withsharedmemory(nd, np, mass);
	cuda_compute_kineticenergy_withsharedmemory(nd, np, mass);
	
	// [K4nsh] kernel 4 without shared memory : cuda_compute_kineticenergy_withoutsharedmemory(nd, np, mass);
	cuda_compute_kineticenergy_withoutsharedmemory(nd, np, mass);
	
	// [K5] kernel 5 : cuda_update_pos(nd, np, dt);
	cuda_update_pos(nd, np, dt);
	
	// [K6] kernel 6 : cuda_update_vel(nd, np, dt, rmass);
	cuda_update_vel(nd, np, dt, rmass);
	
	// [K7] kernel 7 : cuda_update_acc(nd, np, rmass);
	cuda_update_acc(nd, np, rmass);
	
	// [K567M] merged launch of kernals 5, 6 and 7 : cuda_mergedupdate_pos_vel_acc(nd, np, dt, rmass);
	cuda_mergedupdate_pos_vel_acc(nd, np, dt, rmass);

	// [K567S] sequential launch of three kernels 5,6 and 7 : cuda_sequentialupdate_pos_vel_acc(nd, np, dt, rmass);
    cuda_sequentialupdate_pos_vel_acc(nd, np, dt, rmass);
	
	// [K23Ssh] sequential launch of two kernels 2 and 3 with shared memory : cuda_sequentiallaunch_withsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);
	cuda_sequentiallaunch_withsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);
	
	// [K23Snsh] sequential launch of two kernels 2 and 3 without shared memory : cuda_sequentiallaunch_withoutsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);
	cuda_sequentiallaunch_withoutsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);
	
	// [K23Psh] parallel launch of two kernels 2 and 3 with shared memory : cuda_parallellaunch_withsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);
	cuda_parallellaunch_withsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);

	// [K23Pnsh] parallel launch of two kernels 2 and 3 with shared memory : cuda_parallellaunch_withoutsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);
	cuda_parallellaunch_withoutsharedmemory_cumulate_parpot_and_parforce(nd, np, 1);

	
	readArrayFromGPU_acc(acc, nd * np);
	readArrayFromGPU_force(force, nd * np);
	readArrayFromGPU_parforce(parforce, nd * np);
	readArrayFromGPU_pos(pos, nd * np);
	readArrayFromGPU_parpot(parpot, np);
	readArrayFromGPU_vel(vel, nd * np);
	readArrayFromGPU_velnew(velnew, nd * np);
	readArrayFromGPU_accnew(accnew, nd * np);
    freeArrayFromGPU_acc();
	freeArrayFromGPU_force();
	freeArrayFromGPU_vel();
	freeArrayFromGPU_pos();
	freeArrayFromGPU_parpot();
	freeArrayFromGPU_parforce();
    freeArrayFromGPU_velnew();
    freeArrayFromGPU_accnew();

}




void initialize() {
    int i;
    int j;

    seed = 123456789;
    srand(seed);


    // Start by setting the positions to random numbers between 0 and 1

    //    while (index != 0) {
    //    pos[--index] = (double)rand()/((double)(RAND_MAX)+1.0);
    //    }
    
    // Set the dimensions of the box
    int index = nd;
    while (index != 0) {
        box[--index] = 10.0;
    }

    double temp = 0.0;
    for (j = 0; j < np; j++) {
    pos[j] = temp;
    pos[j + np] = temp;
    pos[j + np + np] = temp;
    temp = temp + 0.0000001;
    }

    //Use these random values as scale factors to pick random locations
    //inside the box.
    for (i = 0; i < nd; i++) {
    for (j = 0; j < np; j++) {
        int tempIndex = i * np + j;
        pos[tempIndex] = box[i] * pos[tempIndex];
    }
    }


    //Velocities and accelerations begin at 0
    for (i = 0; i < nd; i++) {
    for (j = 0; j < np; j++) {
        int tempIndex = i * np + j;
        vel[tempIndex] = 0.0;
        acc[tempIndex] = 0.0;
    }
    }
}

#endif
