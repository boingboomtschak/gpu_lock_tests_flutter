CXXFLAGS = -std=c++17

all: vk_lock_test

vk_lock_test: vk_lock_test.cpp easyvk.o tas_lock.cinit ttas_lock.cinit cas_lock.cinit tas_lock_fenced.cinit ttas_lock_fenced.cinit cas_lock_fenced.cinit
	$(CXX) $(CXXFLAGS) easyvk.o vk_lock_test.cpp -lvulkan -o vk_lock_test.run

easyvk.o: easyvk.cpp easyvk.h
	$(CXX) $(CXXFLAGS) -c easyvk.cpp

%.spv: %.cl
	clspv -cl-std=CL2.0 -inline-entry-points $< -o $@

%.cinit: %.cl
	clspv -cl-std=CL2.0 -inline-entry-points -output-format=c $< -o $@

clean:
	rm *.o
	rm *.run
	rm *.cinit
	rm *.spv