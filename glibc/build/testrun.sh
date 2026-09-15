#!/bin/bash
builddir=`dirname "$0"`
GCONV_PATH="${builddir}/iconvdata"

usage () {
cat << EOF
Usage: $0 [OPTIONS] <program> [ARGUMENTS...]

  --tool=TOOL  Run with the specified TOOL. It can be strace, rpctrace,
               valgrind or container. The container will run within
               support/test-container.  For strace and valgrind,
               additional arguments can be passed after the tool name.
EOF

  exit 1
}

toolname=default
while test $# -gt 0 ; do
  case "$1" in
    --tool=*)
      toolname="${1:7}"
      shift
      ;;
    --*)
      usage
      ;;
    *)
      break
      ;;
  esac
done

if test $# -eq 0 ; then
  usage
fi

case "$toolname" in
  default)
    exec   env GCONV_PATH="${builddir}"/iconvdata LOCPATH="${builddir}"/localedata LC_ALL=C  "${builddir}"/elf/ld-linux-x86-64.so.2 --library-path "${builddir}":"${builddir}"/math:"${builddir}"/elf:"${builddir}"/dlfcn:"${builddir}"/nss:"${builddir}"/nis:"${builddir}"/rt:"${builddir}"/resolv:"${builddir}"/mathvec:"${builddir}"/support:"${builddir}"/nptl ${1+"$@"}
    ;;
  strace*)
    exec $toolname  -EGCONV_PATH=/home/ethan/AshDOS-main/glibc/build/iconvdata  -ELOCPATH=/home/ethan/AshDOS-main/glibc/build/localedata  -ELC_ALL=C  /home/ethan/AshDOS-main/glibc/build/elf/ld-linux-x86-64.so.2 --library-path /home/ethan/AshDOS-main/glibc/build:/home/ethan/AshDOS-main/glibc/build/math:/home/ethan/AshDOS-main/glibc/build/elf:/home/ethan/AshDOS-main/glibc/build/dlfcn:/home/ethan/AshDOS-main/glibc/build/nss:/home/ethan/AshDOS-main/glibc/build/nis:/home/ethan/AshDOS-main/glibc/build/rt:/home/ethan/AshDOS-main/glibc/build/resolv:/home/ethan/AshDOS-main/glibc/build/mathvec:/home/ethan/AshDOS-main/glibc/build/support:/home/ethan/AshDOS-main/glibc/build/nptl ${1+"$@"}
    ;;
  rpctrace)
    exec rpctrace  -EGCONV_PATH=/home/ethan/AshDOS-main/glibc/build/iconvdata  -ELOCPATH=/home/ethan/AshDOS-main/glibc/build/localedata  -ELC_ALL=C  /home/ethan/AshDOS-main/glibc/build/elf/ld-linux-x86-64.so.2 --library-path /home/ethan/AshDOS-main/glibc/build:/home/ethan/AshDOS-main/glibc/build/math:/home/ethan/AshDOS-main/glibc/build/elf:/home/ethan/AshDOS-main/glibc/build/dlfcn:/home/ethan/AshDOS-main/glibc/build/nss:/home/ethan/AshDOS-main/glibc/build/nis:/home/ethan/AshDOS-main/glibc/build/rt:/home/ethan/AshDOS-main/glibc/build/resolv:/home/ethan/AshDOS-main/glibc/build/mathvec:/home/ethan/AshDOS-main/glibc/build/support:/home/ethan/AshDOS-main/glibc/build/nptl ${1+"$@"}
    ;;
  valgrind*)
    exec env GCONV_PATH=/home/ethan/AshDOS-main/glibc/build/iconvdata LOCPATH=/home/ethan/AshDOS-main/glibc/build/localedata LC_ALL=C $toolname  /home/ethan/AshDOS-main/glibc/build/elf/ld-linux-x86-64.so.2 --library-path /home/ethan/AshDOS-main/glibc/build:/home/ethan/AshDOS-main/glibc/build/math:/home/ethan/AshDOS-main/glibc/build/elf:/home/ethan/AshDOS-main/glibc/build/dlfcn:/home/ethan/AshDOS-main/glibc/build/nss:/home/ethan/AshDOS-main/glibc/build/nis:/home/ethan/AshDOS-main/glibc/build/rt:/home/ethan/AshDOS-main/glibc/build/resolv:/home/ethan/AshDOS-main/glibc/build/mathvec:/home/ethan/AshDOS-main/glibc/build/support:/home/ethan/AshDOS-main/glibc/build/nptl ${1+"$@"}
    ;;
  container)
    exec env GCONV_PATH=/home/ethan/AshDOS-main/glibc/build/iconvdata LOCPATH=/home/ethan/AshDOS-main/glibc/build/localedata LC_ALL=C  /home/ethan/AshDOS-main/glibc/build/elf/ld-linux-x86-64.so.2 --library-path /home/ethan/AshDOS-main/glibc/build:/home/ethan/AshDOS-main/glibc/build/math:/home/ethan/AshDOS-main/glibc/build/elf:/home/ethan/AshDOS-main/glibc/build/dlfcn:/home/ethan/AshDOS-main/glibc/build/nss:/home/ethan/AshDOS-main/glibc/build/nis:/home/ethan/AshDOS-main/glibc/build/rt:/home/ethan/AshDOS-main/glibc/build/resolv:/home/ethan/AshDOS-main/glibc/build/mathvec:/home/ethan/AshDOS-main/glibc/build/support:/home/ethan/AshDOS-main/glibc/build/nptl /home/ethan/AshDOS-main/glibc/build/support/test-container env GCONV_PATH=/home/ethan/AshDOS-main/glibc/build/iconvdata LOCPATH=/home/ethan/AshDOS-main/glibc/build/localedata LC_ALL=C  /home/ethan/AshDOS-main/glibc/build/elf/ld-linux-x86-64.so.2 --library-path /home/ethan/AshDOS-main/glibc/build:/home/ethan/AshDOS-main/glibc/build/math:/home/ethan/AshDOS-main/glibc/build/elf:/home/ethan/AshDOS-main/glibc/build/dlfcn:/home/ethan/AshDOS-main/glibc/build/nss:/home/ethan/AshDOS-main/glibc/build/nis:/home/ethan/AshDOS-main/glibc/build/rt:/home/ethan/AshDOS-main/glibc/build/resolv:/home/ethan/AshDOS-main/glibc/build/mathvec:/home/ethan/AshDOS-main/glibc/build/support:/home/ethan/AshDOS-main/glibc/build/nptl ${1+"$@"}
    ;;
  *)
    usage
    ;;
esac
