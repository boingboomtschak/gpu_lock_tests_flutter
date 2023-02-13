#include <stdexcept>
#include <stdarg.h>
#include <string>

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

extern "C" char* run(
    uint32_t workgroups = 16,
    uint32_t lock_iters = 1000,
    uint32_t test_iters = 16
) {
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
    vector<Buffer> buffers = { lockBuf, resultBuf, lockItersBuf };
    lockItersBuf.store(0, lock_iters);

    // -------------- TAS LOCK --------------

    log("----------------------------------------------------------\n");
    log("Testing TAS lock...\n");
    log("%d workgroups, %d locks per thread, tests run %d times.\n", workgroups, lock_iters, test_iters);
    vector<uint32_t> tasSpvCode =
    #include "tas_lock.cinit"
    ;
    Program tasProgram = Program(device, tasSpvCode, buffers);
    tasProgram.setWorkgroups(workgroups);
    tasProgram.setWorkgroupSize(1);
    tasProgram.prepare();
    uint32_t tas_failures = 0;

    for (int i = 1; i <= test_iters; i++) {
        log("  Test %d: ", i);
        lockBuf.clear();
        resultBuf.clear();

        tasProgram.run();

        uint32_t result = resultBuf.load(0);
        uint32_t test_failures = (lock_iters * workgroups) - result;
        float test_percent = (float)test_failures / (float)test_total * 100;

        if (test_percent > 10.0)
            log("\u001b[31m");
        else if (test_percent > 5.0)
            log("\u001b[33m");
        else
            log("\u001b[32m");
        log("%d / %d, %.2f%%\u001b[0m\n", test_failures, test_total, test_percent);
        tas_failures += test_failures;
    }
    float tas_failure_percent = (float)tas_failures / (float)total_locks * 100;
    log("%d / %d failures, about %.2f%%\n", tas_failures, total_locks, tas_failure_percent);

    // -------------- TTAS LOCK --------------

    log("----------------------------------------------------------\n");
    log("Testing TTAS lock...\n");
    log("%d workgroups, %d locks per thread, tests run %d times.\n", workgroups, lock_iters, test_iters);
    vector<uint32_t> ttasSpvCode =
    #include "ttas_lock.cinit"
    ;
    Program ttasProgram = Program(device, ttasSpvCode, buffers);
    ttasProgram.setWorkgroups(workgroups);
    ttasProgram.setWorkgroupSize(1);
    ttasProgram.prepare();
    uint32_t ttas_failures = 0;

    for (int i = 1; i <= test_iters; i++) {
        log("  Test %d: ", i);
        lockBuf.clear();
        resultBuf.clear();

        ttasProgram.run();

        uint32_t result = resultBuf.load(0);
        uint32_t test_failures = (lock_iters * workgroups) - result;
        float test_percent = (float)test_failures / (float)test_total * 100;

        if (test_percent > 10.0)
            log("\u001b[31m");
        else if (test_percent > 5.0)
            log("\u001b[33m");
        else
            log("\u001b[32m");
        log("%d / %d, %.2f%%\u001b[0m\n", test_failures, test_total, test_percent);
        ttas_failures += test_failures;
    }
    float ttas_failure_percent = (float)ttas_failures / (float)total_locks * 100;
    log("%d / %d failures, about %.2f%%\n", ttas_failures, total_locks, ttas_failure_percent);

    // -------------- CAS LOCK --------------

    log("----------------------------------------------------------\n");
    log("Testing CAS lock...\n");
    log("%d workgroups, %d locks per thread, tests run %d times.\n", workgroups, lock_iters, test_iters);
    vector<uint32_t> casSpvCode =
    #include "cas_lock.cinit"
    ;
    Program casProgram = Program(device, casSpvCode, buffers);
    casProgram.setWorkgroups(workgroups);
    casProgram.setWorkgroupSize(1);
    casProgram.prepare();
    uint32_t cas_failures = 0;

    for (int i = 1; i <= test_iters; i++) {
        log("  Test %d: ", i);
        lockBuf.clear();
        resultBuf.clear();

        casProgram.run();

        uint32_t result = resultBuf.load(0);
        uint32_t test_failures = (lock_iters * workgroups) - result;
        float test_percent = (float)test_failures / (float)test_total * 100;

        if (test_percent > 10.0)
            log("\u001b[31m");
        else if (test_percent > 5.0)
            log("\u001b[33m");
        else
            log("\u001b[32m");
        log("%d / %d, %.2f%%\u001b[0m\n", test_failures, test_total, test_percent);
        cas_failures += test_failures;
    }
    float cas_failure_percent = (float)cas_failures / (float)total_locks * 100;
    log("%d / %d failures, about %.2f%%\n", cas_failures, total_locks, cas_failure_percent);

    log("----------------------------------------------------------\n");
    log("Cleaning up...\n");

    tasProgram.teardown();
    ttasProgram.teardown();
    casProgram.teardown();

    lockItersBuf.teardown();
    resultBuf.teardown();
    lockBuf.teardown();
        
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
        {"ttas-failures", ttas_failures},
        {"ttas-failure-percent", ttas_failure_percent},
        {"cas-failures", cas_failures},
        {"cas-failure-percent", cas_failure_percent}
    };

    string json_string = result_json.dump();
    char* json_cstring = new char[json_string.size() + 1];
    copy(json_string.data(), json_string.data() + json_string.size() + 1, json_cstring);
    return json_cstring;
}

int main() {
    char* res = run();
    log("%s\n", res);
    delete[] res;
    return 0;
}