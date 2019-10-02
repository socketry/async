# (All) Rubies Benchmark

This is a simple benchmark, which reads and writes data over a pipe.

It is designed to work as far back as Ruby 1.9.3 at the expense of code clarity. It also works on JRuby and TruffleRuby.

## Usage

The simplest way is to use RVM.

	rvm all do ./benchmark.rb

## Results

General improvements.

	ruby 1.9.3p551 (2014-11-13 revision 48407) [x86_64-linux]
	#<struct Struct::Tms utime=63.41, stime=7.15, cutime=0.0, cstime=0.0>

	ruby 2.0.0p648 (2015-12-16 revision 53162) [x86_64-linux]
	#<struct Struct::Tms utime=59.5, stime=6.57, cutime=0.0, cstime=0.0>

	ruby 2.1.10p492 (2016-04-01 revision 54464) [x86_64-linux]
	#<struct Process::Tms utime=40.53, stime=6.87, cutime=0.0, cstime=0.0>

	ruby 2.2.10p489 (2018-03-28 revision 63023) [x86_64-linux]
	#<struct Process::Tms utime=41.26, stime=6.62, cutime=0.0, cstime=0.0>

	ruby 2.3.8p459 (2018-10-18 revision 65136) [x86_64-linux]
	#<struct Process::Tms utime=31.85, stime=6.55, cutime=0.0, cstime=0.0>

	ruby 2.4.6p354 (2019-04-01 revision 67394) [x86_64-linux]
	#<struct Process::Tms utime=41.89, stime=6.72, cutime=0.0, cstime=0.0>

	ruby 2.5.3p105 (2018-10-18 revision 65156) [x86_64-linux]
	#<struct Process::Tms utime=26.446285, stime=6.549777, cutime=0.0, cstime=0.0>

Native fiber implementation & reduced syscalls (https://bugs.ruby-lang.org/issues/14739).

	ruby 2.6.3p62 (2019-04-16 revision 67580) [x86_64-linux]
	#<struct Process::Tms utime=20.045192, stime=5.5941600000000005, cutime=0.0, cstime=0.0>

Performance regression (https://bugs.ruby-lang.org/issues/16009).

	ruby 2.7.0preview1 (2019-05-31 trunk c55db6aa271df4a689dc8eb0039c929bf6ed43ff) [x86_64-linux]
	#<struct Process::Tms utime=25.193268, stime=5.808202, cutime=0.0, cstime=0.0>

Improve fiber performance using pool alloation strategy (https://bugs.ruby-lang.org/issues/15997).

	ruby 2.7.0dev (2019-10-02T08:19:14Z trunk 9759e3c9f0) [x86_64-linux]
	#<struct Process::Tms utime=19.110835, stime=5.738776, cutime=0.0, cstime=0.0>
