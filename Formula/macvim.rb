# frozen_string_literal: true

# Reference: https://github.com/macvim-dev/macvim/wiki/building
class Macvim < Formula
  desc "GUI for vim, made for macOS"
  homepage "https://github.com/macvim-dev/macvim"
  url "https://github.com/macvim-dev/macvim/archive/snapshot-146.tar.gz"
  version "8.0-146"
  sha256 "f13f2448ea17756d5d6f6a9e5cd1b933fa6f05c393d7848f35198b5b4a16105e"
  revision 1
  head "https://github.com/macvim-dev/macvim.git"

  bottle do
    sha256 "9150724774b95837fabbcd245e992119bd7c00d88c6a2b41a345c0471ed4b831" => :high_sierra
    sha256 "b8ff3db922ebc801bce4d998082c0cdfc76dc82bbcd55fcef840298bc1c4df97" => :sierra
    sha256 "c86706fc3141fdd2ed22188de2e49481c83b1fdb61c9c26f53fe5fdcd2b29638" => :el_capitan
  end

  option "with-override-system-vim", "Override system vim"
  option "with-dynamic-ruby", "Build with dynamic ruby support"
  option "with-dynamic-python", "Build with dynamic python support"

  deprecated_option "override-system-vim" => "with-override-system-vim"

  depends_on :xcode => :build
  depends_on "cscope" => :recommended
  depends_on "python" => :recommended
  depends_on "lua" => :optional
  depends_on "ruby" => :recommended

  def install
    # Avoid issues finding Ruby headers
    if MacOS.version == :sierra || MacOS.version == :yosemite
      ENV.delete("SDKROOT")
    end

    # MacVim doesn't have or require any Python package, so unset PYTHONPATH
    ENV.delete("PYTHONPATH")

    # If building for OS X 10.7 or up, make sure that CC is set to "clang"
    ENV.clang if MacOS.version >= :lion

    args = %W[
      --with-features=huge
      --enable-multibyte
      --with-macarchs=#{MacOS.preferred_arch}
      --enable-perlinterp
      --enable-tclinterp
      --enable-terminal
      --with-tlib=ncurses
      --with-compiledby=HomebrewCustom
      --with-local-dir=#{HOMEBREW_PREFIX}
    ]

    args << "--enable-cscope" if build.with? "cscope"

    if build.with? "lua"
      args << "--enable-luainterp"
      args << "--with-lua-prefix=#{Formula["lua"].opt_prefix}"
    end

    if build.with? "dynamic-ruby"
      args << "--enable-rubyinterp=dynamic"
    else
      args << "--enable-rubyinterp"
    end

    if build.with? "dynamic-python"
      args << "--enable-python3interp=dynamic"
    else
      args << "--enable-python3interp"
    end

    system "./configure", *args
    system "make"

    prefix.install "src/MacVim/build/Release/MacVim.app"
    bin.install_symlink prefix/"MacVim.app/Contents/bin/mvim"

    # Create MacVim vimdiff, view, ex equivalents
    executables = %w[mvimdiff mview mvimex gvim gvimdiff gview gvimex]
    executables += %w[vi vim vimdiff view vimex] if build.with? "override-system-vim"
    executables.each { |e| bin.install_symlink "mvim" => e }
  end

  test do
    output = shell_output("#{bin}/mvim --version")
    assert_match "+ruby", output

    # Simple test to check if MacVim was linked to Homebrew's Python 3
    if build.with? "python"
      py3_exec_prefix = Utils.popen_read("python3-config", "--exec-prefix")
      assert_match py3_exec_prefix.chomp, output
      (testpath/"commands.vim").write <<~EOS
        :python3 import vim; vim.current.buffer[0] = 'hello python3'
        :wq
      EOS
      system bin/"mvim", "-v", "-T", "dumb", "-s", "commands.vim", "test.txt"
      assert_equal "hello python3", (testpath/"test.txt").read.chomp
    end
  end
end
