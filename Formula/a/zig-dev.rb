class ZigDev < Formula
    desc "Programming language designed for robustness, optimality, and clarity"
    homepage "https://ziglang.org/"
    # TODO: Check if we can use unversioned `llvm` at version bump.
    url "https://ziglang.org/builds/zig-0.12.0-dev.1710+2bffd8101.tar.xz"
    sha256 "c6a822fd79bd98c5d1883620fd32c605a77e8bdc8e570dfaf1b8aa3197ffb8c9"
    license "MIT"
  
    livecheck do
      url "https://ziglang.org/download/"
      regex(/href=.*?zig[._-]v?(\d+(?:\.\d+)+)\.t/i)
    end
  
    depends_on "cmake" => :build
    # Check: https://github.com/ziglang/zig/blob/#{version}/CMakeLists.txt
    # for supported LLVM version.
    # When switching to `llvm`, remove the `on_linux` block below.
    depends_on "llvm@17" => :build
    depends_on macos: :big_sur # https://github.com/ziglang/zig/issues/13313
    depends_on "z3"
    depends_on "zstd"
    uses_from_macos "ncurses"
    uses_from_macos "zlib"
  
    # `llvm` is not actually used, but we need it because `brew`'s compiler
    # selector does not currently support using Clang from a versioned LLVM.
    on_linux do
      depends_on "llvm" => :build
    end
  
    fails_with :gcc
  
    def install
      # Make sure `llvm@16` is used.
      ENV.prepend_path "PATH", Formula["llvm@17"].opt_bin
      ENV["CC"] = Formula["llvm@17"].opt_bin/"clang"
      ENV["CXX"] = Formula["llvm@17"].opt_bin/"clang++"
  
      # Work around duplicate symbols with Xcode 15 linker.
      # Remove on next release.
      # https://github.com/ziglang/zig/issues/17050
      ENV.append "LDFLAGS", "-Wl,-ld_classic" if DevelopmentTools.clang_build_version >= 1500
  
      # Workaround for https://github.com/Homebrew/homebrew-core/pull/141453#discussion_r1320821081.
      # This will likely be fixed upstream by https://github.com/ziglang/zig/pull/16062.
      if OS.linux?
        ENV["NIX_LDFLAGS"] = ENV["HOMEBREW_RPATH_PATHS"].split(":")
                                                        .map { |p| "-rpath #{p}" }
                                                        .join(" ")
      end
  
      cpu = case Hardware.oldest_cpu
      when :arm_vortex_tempest then "apple_m1" # See `zig targets`.
      else Hardware.oldest_cpu
      end
  
      args = ["-DZIG_STATIC_LLVM=ON"]
      args << "-DZIG_TARGET_MCPU=#{cpu}" if build.bottle?
  
      system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
      system "cmake", "--build", "build"
      system "cmake", "--install", "build"
    end
  
    test do
      (testpath/"hello.zig").write <<~EOS
        const std = @import("std");
        pub fn main() !void {
            const stdout = std.io.getStdOut().writer();
            try stdout.print("Hello, world!", .{});
        }
      EOS
      system "#{bin}/zig", "build-exe", "hello.zig"
      assert_equal "Hello, world!", shell_output("./hello")
  
      # error: 'TARGET_OS_IPHONE' is not defined, evaluates to 0
      # https://github.com/ziglang/zig/issues/10377
      ENV.delete "CPATH"
      (testpath/"hello.c").write <<~EOS
        #include <stdio.h>
        int main() {
          fprintf(stdout, "Hello, world!");
          return 0;
        }
      EOS
      system "#{bin}/zig", "cc", "hello.c", "-o", "hello"
      assert_equal "Hello, world!", shell_output("./hello")
    end
  end
