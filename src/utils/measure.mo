import Debug "mo:base/Debug";
import Prim "mo:⛔";

module {
  public class Measure(verbose : Bool) {
    public func header() {
      if (verbose) Debug.print(
        debug_show (
          "time",
          "rts_heap_size",
          "rts_mutator_instructions",
          "rts_collector_instructions",
          "performanceCounter",
          "stableVarQuery",
        )
      );
    };

    public func test(time : Text) {
      if (verbose) Debug.print(
        debug_show (
          time,
          Prim.rts_heap_size(),
          Prim.rts_mutator_instructions(),
          Prim.rts_collector_instructions(),
          Prim.performanceCounter(0),
        )
      );
    };

    public func test_async(time : Text) : async () {
      if (verbose) Debug.print(
        debug_show (
          time,
          Prim.rts_heap_size(),
          Prim.rts_mutator_instructions(),
          Prim.rts_collector_instructions(),
          Prim.performanceCounter(0),
          (await Prim.stableVarQuery()()).size,
        )
      );
    };
  };
};
