#!/usr/bin/env bash
# Run the examples of a TARGET=DYNAMIC build (in ./build) with every bundled
# target and with automatic selection (BLASFEO_TARGET empty).
#   RUN             command prefix running a binary (e.g. qemu-arm -L ...)
#   KNOWN_FAILURES  <target>/<example> entries expected to fail

(grep -m3 -iE "model name|CPU part|flags" /proc/cpuinfo || sysctl -n machdep.cpu.brand_string) 2>/dev/null | cut -c1-120
targets=$(sed -n 's/^static const char \*const dynamic_targets.*{ \(.*\) };/\1/p' build/dynamic/gen/blasfeo_dynamic_table.inc | tr -d '",')
echo "bundled: $targets"
fail=0
# no executable stack (ELF)
if [ -f build/libblasfeo-dynamic.so ] && readelf -lW build/libblasfeo-dynamic.so | grep GNU_STACK | grep -q RWE; then
	echo "FAIL  libblasfeo-dynamic.so requires an executable stack"; fail=1
fi
for t in "" $targets; do
	echo "::group::BLASFEO_TARGET=$t"
	export BLASFEO_TARGET=$t
	$RUN ./build/examples/example_dynamic_target > out.txt 2>&1 || fail=1
	cat out.txt
	sel=$(sed -n 's/^target \([^,]*\),.*/\1/p' out.txt)
	for e in getting_started example_d_lu_factorization example_d_lq_factorization example_d_riccati_recursion example_s_lu_factorization example_s_riccati_recursion; do
		if $RUN ./build/examples/$e > log.txt 2>&1; then
			echo "ok    $sel $e"
		elif [[ " $KNOWN_FAILURES " == *" $sel/$e "* ]]; then
			echo "known $sel $e"
		else
			echo "FAIL  $sel $e"; tail -5 log.txt; fail=1
		fi
	done
	echo "::endgroup::"
done
exit $fail
