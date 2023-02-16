#include <stdexcept>
#include <stdarg.h>
#include <string>
#include <chrono>

#include "easyvk.h"
#include "json.h"

#ifdef __ANDROID__
#include <android/log.h>
#define APPNAME "GPULockTests"
#endif

using std::vector;
using std::runtime_error;
using std::string;
using std::copy;
using nlohmann::json;
using easyvk::Instance;
using easyvk::Device;
using easyvk::Buffer;
using easyvk::Program;
using easyvk::vkDeviceType;
using namespace std::chrono;

const char* os_name() {
    #ifdef _WIN32
    return "Windows (32-bit)";
    #elif _WIN64
    return "Windows (64-bit)";
    #elif __APPLE__
        #include <TargetConditionals.h>
        #if TARGET_IPHONE_SIMULATOR
        return "iPhone (Simulator)";
        #elif TARGET_OS_MACCATALYST
        return "macOS Catalyst";
        #elif TARGET_OS_IPHONE
        return "iPhone";
        #elif TARGET_OS_MAC
        return "macOS";
        #else
        return "Other (Apple)";
        #endif
    #elif __ANDROID__
    return "Android";
    #elif __linux__
    return "Linux";
    #elif __unix || __unix||
    return "Unix";
    #else
    return "Other";
    #endif
}

void log(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    #ifdef __ANDROID__
    __android_log_vprint(ANDROID_LOG_INFO, APPNAME, fmt, args);
    #else
    vprintf(fmt, args);
    #endif
    va_end(args);
}

extern "C" char* run(uint32_t workgroups, uint32_t workgroup_size, uint32_t lock_iters, uint32_t test_iters) {
    log("Initializing test...\n");

    Instance instance = Instance(false);
    Device device = instance.devices().at(0);

    log("Using device '%s'\n", device.properties.deviceName);

    uint32_t maxComputeWorkGroupInvocations = device.properties.limits.maxComputeWorkGroupInvocations;
    log("MaxComputeWorkGroupInvocations: %d\n", maxComputeWorkGroupInvocations);
    if (workgroups > maxComputeWorkGroupInvocations)
        workgroups = maxComputeWorkGroupInvocations;

    uint32_t test_total = workgroups * lock_iters;
    uint32_t total_locks = test_total * test_iters;

    Buffer lockBuf = Buffer(device, 1);
    Buffer resultBuf = Buffer(device, 1);
    Buffer lockItersBuf = Buffer(device, 1);
    Buffer garbageBuf = Buffer(device, workgroups * workgroup_size);
    vector<Buffer> buffers = { lockBuf, resultBuf, lockItersBuf, garbageBuf };
    lockItersBuf.store(0, lock_iters);

    // -------------- TAS LOCK --------------

    uint32_t tas_failures = 0;
    uint32_t tas_iter_failures = 0;


    log("----------------------------------------------------------\n");
    log("Testing TAS lock...\n");
    log("%d workgroups, %d threads per workgroup, %d locks per thread, tests run %d times.\n", workgroups, workgroup_size, lock_iters, test_iters);
    vector<uint32_t> tasSpvCode =
    #include "tas_lock.cinit"
    ;

    Program tasProgram = Program(device, tasSpvCode, buffers);
    tasProgram.setWorkgroups(workgroups);
    tasProgram.setWorkgroupSize(workgroup_size);
    tasProgram.prepare();

    float tas_test_total_time = 0.0;
    for (int i = 1; i <= test_iters; i++) {
        log("  Test %d: ", i);
        lockBuf.clear();
        resultBuf.clear();

        auto start = high_resolution_clock::now();
        tasProgram.run();
        auto stop = high_resolution_clock::now();
        tas_test_total_time += duration_cast<milliseconds>(stop - start).count() / 1000.0;


        uint32_t result = resultBuf.load(0);
        uint32_t test_failures = (lock_iters * workgroups) - result;
        if (test_failures > 0) {
          tas_iter_failures += 1;
        }
        float test_percent = (float)test_failures / (float)test_total * 100;

        #ifndef __ANDROID__
        if (test_percent > 10.0)
            log("\u001b[31m");
        else if (test_percent > 5.0)
            log("\u001b[33m");
        else
            log("\u001b[32m");
        #endif
        log("%d / %d, %.2f%%\n", test_failures, test_total, test_percent);
        #ifndef __ANDROID__
        log('\u001b[0m');
        #endif
        tas_failures += test_failures;
    }

    float tas_test_avg_time = tas_test_total_time / test_iters;
    float tas_failure_percent = (float)tas_failures / (float)total_locks * 100;
    log("%d / %d failures, about %.2f%%\n", tas_failures, total_locks, tas_failure_percent);
    log("%d / %d iterations failed \n", tas_iter_failures, test_iters);


    // -------------- TTAS LOCK --------------
    uint32_t ttas_failures = 0;
    uint32_t ttas_iter_failures = 0;


    log("----------------------------------------------------------\n");
    log("Testing TTAS lock...\n");
    log("%d workgroups, %d threads per workgroup, %d locks per thread, tests run %d times.\n", workgroups, workgroup_size, lock_iters, test_iters);
    vector<uint32_t> ttasSpvCode =
    #include "ttas_lock.cinit"
    ;
    Program ttasProgram = Program(device, ttasSpvCode, buffers);
    ttasProgram.setWorkgroups(workgroups);
    ttasProgram.setWorkgroupSize(workgroup_size);
    ttasProgram.prepare();

    float ttas_test_total_time = 0.0;
    for (int i = 1; i <= test_iters; i++) {
        log("  Test %d: ", i);
        lockBuf.clear();
        resultBuf.clear();

        auto start = high_resolution_clock::now();
        ttasProgram.run();
        auto stop = high_resolution_clock::now();
        ttas_test_total_time += duration_cast<milliseconds>(stop - start).count() / 1000.0;

        uint32_t result = resultBuf.load(0);
        uint32_t test_failures = (lock_iters * workgroups) - result;
        if (test_failures > 0) {
          ttas_iter_failures += 1;
        }
        float test_percent = (float)test_failures / (float)test_total * 100;

        #ifndef __ANDROID__
        if (test_percent > 10.0)
            log("\u001b[31m");
        else if (test_percent > 5.0)
            log("\u001b[33m");
        else
            log("\u001b[32m");
        #endif
        log("%d / %d, %.2f%%\n", test_failures, test_total, test_percent);
        #ifndef __ANDROID__
        log('\u001b[0m');
        #endif
        ttas_failures += test_failures;
    }

    float ttas_test_avg_time = ttas_test_total_time / test_iters;
    float ttas_failure_percent = (float)ttas_failures / (float)total_locks * 100;
    log("%d / %d failures, about %.2f%%\n", ttas_failures, total_locks, ttas_failure_percent);
    log("%d / %d iterations failed \n", ttas_iter_failures, test_iters);


    // -------------- CAS LOCK --------------

    uint32_t cas_failures = 0;
    uint32_t cas_iter_failures = 0;


    log("----------------------------------------------------------\n");
    log("Testing CAS lock...\n");
    log("%d workgroups, %d threads per workgroup, %d locks per thread, tests run %d times.\n", workgroups, workgroup_size, lock_iters, test_iters);
    vector<uint32_t> casSpvCode =
    #include "cas_lock.cinit"
    ;
    Program casProgram = Program(device, casSpvCode, buffers);
    casProgram.setWorkgroups(workgroups);
    casProgram.setWorkgroupSize(workgroup_size);
    casProgram.prepare();

    float cas_test_total_time = 0.0;
    for (int i = 1; i <= test_iters; i++) {
        log("  Test %d: ", i);
        lockBuf.clear();
        resultBuf.clear();

        auto start = high_resolution_clock::now();
        casProgram.run();
        auto stop = high_resolution_clock::now();
        cas_test_total_time += duration_cast<milliseconds>(stop - start).count() / 1000.0;

        uint32_t result = resultBuf.load(0);
        uint32_t test_failures = (lock_iters * workgroups) - result;
        if (test_failures > 0) {
          cas_iter_failures += 1;
        }

        float test_percent = (float)test_failures / (float)test_total * 100;

        #ifndef __ANDROID__
        if (test_percent > 10.0)
            log("\u001b[31m");
        else if (test_percent > 5.0)
            log("\u001b[33m");
        else
            log("\u001b[32m");
        #endif
        log("%d / %d, %.2f%%\n", test_failures, test_total, test_percent);
        #ifndef __ANDROID__
        log('\u001b[0m');
        #endif
        cas_failures += test_failures;
    }

    float cas_test_avg_time = cas_test_total_time / test_iters;
    float cas_failure_percent = (float)cas_failures / (float)total_locks * 100;
    log("%d / %d failures, about %.2f%%\n", cas_failures, total_locks, cas_failure_percent);
    log("%d / %d iterations failed \n", cas_iter_failures, test_iters);

    log("----------------------------------------------------------\n");
    log("Cleaning up...\n");

    tasProgram.teardown();
    ttasProgram.teardown();
    casProgram.teardown();

    lockItersBuf.teardown();
    resultBuf.teardown();
    lockBuf.teardown();
    garbageBuf.teardown();
        
    device.teardown();
    instance.teardown();

    json result_json = {
        {"os-name", os_name()},
        {"device-name", device.properties.deviceName},
        {"device-type", vkDeviceType(device.properties.deviceType)},
        {"workgroups", workgroups},
        {"lock-iters", lock_iters},
        {"test-iters", test_iters},
        {"total-locks", total_locks},
        {"tas-failures", tas_failures},
        {"tas-failure-percent", tas_failure_percent},
        {"tas-iter-failures", tas_iter_failures},
        {"tas-test-avg-time", tas_test_avg_time},
        {"tas-test-total-time", tas_test_total_time},
        {"ttas-failures", ttas_failures},
        {"ttas-failure-percent", ttas_failure_percent},
        {"ttas-iter-failures", ttas_iter_failures},
        {"ttas-test-avg-time", ttas_test_avg_time},
        {"ttas-test-total-time", ttas_test_total_time},
        {"cas-failures", cas_failures},
        {"cas-failure-percent", cas_failure_percent},
        {"cas-iter-failures", cas_iter_failures},
        {"cas-test-avg-time", cas_test_avg_time},
        {"cas-test-total-time", cas_test_total_time}
    };

    string json_string = result_json.dump();
    char* json_cstring = new char[json_string.size() + 1];
    copy(json_string.data(), json_string.data() + json_string.size() + 1, json_cstring);
    return json_cstring;
}

extern "C" char* run_default() {
    return run(8, 16, 2000, 16);
}

int main() {
    char* res = run_default();
    log("%s\n", res);
    delete[] res;
    return 0;
}