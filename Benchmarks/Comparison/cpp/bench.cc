// The C++ peer of the comparison (roadmap 0012): code protoc --cpp_out writes for comparison.proto, over the libprotobuf of the
// installed protoc, timing the message the Swift codecs time (users-n2000.bin, written by ComparisonSizes --write).
//
//   Scripts/compare.sh cpp
//
// Wall clock, the median and 90th percentile of at least 200 samples or two seconds, as package-benchmark reports them.
#include <algorithm>
#include <cstdlib>
#include <chrono>
#include <cstdio>
#include <fstream>
#include <functional>
#include <iterator>
#include <string>
#include <vector>

#include "comparison.pb.h"
#include "google/protobuf/arena.h"

namespace {

struct Percentiles {
    double p50;
    double p90;
};

Percentiles Measure(const std::function<void()>& body) {
    using Clock = std::chrono::steady_clock;
    std::vector<double> samples;
    const auto deadline = Clock::now() + std::chrono::seconds(2);
    while (samples.size() < 200 || Clock::now() < deadline) {
        const auto start = Clock::now();
        body();
        samples.push_back(std::chrono::duration<double, std::micro>(Clock::now() - start).count());
        if (samples.size() >= 50000) break;
    }
    std::sort(samples.begin(), samples.end());
    return {samples[samples.size() / 2], samples[samples.size() * 9 / 10]};
}

}  // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: bench users-n2000.bin\n");
        return 2;
    }
    std::ifstream file(argv[1], std::ios::binary);
    const std::string bytes((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    Users users;
    if (bytes.empty() || !users.ParseFromString(bytes) || users.users_size() != 2000) {
        std::fprintf(stderr, "cannot read 2,000 users from %s\n", argv[1]);
        return 1;
    }
    std::string out;
    if (!users.SerializeToString(&out) || out != bytes) {
        std::fprintf(stderr, "C++ does not write the bytes it read\n");
        return 1;
    }
    const auto decode = Measure([&] {
        Users decoded;
        if (!decoded.ParseFromString(bytes)) std::abort();
    });
    const auto arena = Measure([&] {
        google::protobuf::Arena arena;
        auto* decoded = google::protobuf::Arena::Create<Users>(&arena);
        if (!decoded->ParseFromString(bytes)) std::abort();
    });
    const auto encode = Measure([&] {
        std::string encoded;
        if (!users.SerializeToString(&encoded)) std::abort();
    });
    std::printf("| task (2,000 records) | p50 | p90 |\n|---|---:|---:|\n");
    std::printf("| decode | %.1f µs | %.1f µs |\n", decode.p50, decode.p90);
    std::printf("| decode into an arena | %.1f µs | %.1f µs |\n", arena.p50, arena.p90);
    std::printf("| encode | %.1f µs | %.1f µs |\n", encode.p50, encode.p90);
    return 0;
}
