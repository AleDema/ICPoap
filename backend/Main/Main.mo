import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import List "mo:base/List";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Bool "mo:base/Bool";
import Principal "mo:base/Principal";
import Types "./Types";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import FileStorage "../Storage/FileStorage";
import Cycles "mo:base/ExperimentalCycles";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Map "mo:map/Map";
import Fuzz "mo:fuzz";
import Prim "mo:prim";
import Iter "mo:base/Iter";
import Timer "mo:base/Timer";
import ICRCTypes "../ledger/Types";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Float "mo:base/Float";
import Time "mo:base/Time";

shared ({ caller }) actor class Main() = Self {

  type Event = {
    id : Text;
    transactionId : Nat;
    nftName : Text;
    description : Text;
    startDate : ?Nat;
    endDate : ?Nat;
    nftType : Text;
    nftUrl : Text;
    limit : ?Nat;
    state : {
      #active;
      #ended;
      #inactive;
    };
    creationDate : Int;
  };

  type CouponStates = {
    #active;
    #frozen;
    #redeemed;
  };

  type Coupon = {
    id : Text;
    startDate : ?Nat;
    endDate : ?Nat;
    amount : Nat;
    state : CouponStates;
    redeemer : ?Principal;
  };

  stable var custodian = caller;
  stable var custodians = List.make<Principal>(custodian);
  let { ihash; nhash; thash; phash; calcHash } = Map;
  stable let events = Map.new<Text, Event>(thash);
  stable let collections = Map.new<Text, Event>(thash);
  stable let coupons = Map.new<Text, Coupon>(thash);
  stable var outstandingCouponsBalance = 0;
  let pthash : Map.HashUtils<(Principal, Text)> = (
    func(key) = (Prim.hashBlob(Prim.blobOfPrincipal(key.0)) +% Prim.hashBlob(Prim.encodeUtf8(key.1))) & 0x3fffffff,
    func(a, b) = a.0 == b.0 and a.1 == b.1,
    func() = (Prim.principalOfBlob(""), ""),
  );
  stable let eventsByPrincipal = Map.new<(Principal, Text), Nat64>(pthash);
  //TODO: add your plug principal here
  custodians := List.push(Principal.fromText("ag4tv-x5mbo-jm4z7-6d7wf-dmplt-qt57w-7slxi-2cjko-2leby-24toe-dae"), custodians);
  custodians := List.push(Principal.fromText("7yz2c-cwrul-2shfg-zebn2-e3ku4-ixlo6-n6aur-2tawv-73veq-xqryc-kae"), custodians);
  custodians := List.push(Principal.fromText("2mz3w-mvsyl-7jyy5-utujh-r3l4n-ww3dm-esjgl-igmix-of4f5-susxa-pqe"), custodians);
  custodians := List.push(Principal.fromText("m2eif-say6u-qkqyb-x57ff-apqcy-phss6-f3k55-5wynb-l3qq5-u4lge-qqe"), custodians);
  custodians := List.push(Principal.fromText("s2e7s-gcq7c-kj7tz-lanqo-w6y6s-ypgss-ltsk2-syyld-k667a-g6cwl-qae"), custodians);
  custodians := List.push(Principal.fromText("ig5qb-sewk3-rxbg6-o7x6w-ns7re-g76um-7wgqr-wcgmp-m53x6-chnps-lae"), custodians);
  custodians := List.push(Principal.fromText("qvpnf-i5sl6-ivj2f-qzood-h364x-kopvb-lxy2k-yh2xf-dh4hg-oy2pl-dqe"), custodians);
  custodians := List.push(Principal.fromText("whaio-wy2tv-opnm3-4ld63-avbfc-zptux-663rl-mhejh-x5szu-45r6s-lqe"), custodians);
  custodians := List.push(Principal.fromText("lthbc-s7c4h-3oo2v-olnlk-kvil4-p34hi-26t5g-4ciyd-di65k-hbh5n-hae"), custodians);
  custodians := List.push(Principal.fromText("ongl2-c2ceb-mfxvy-63cc7-tmil7-xznc6-wmy2y-sqb6f-cs546-2l23t-wae"), custodians);
  custodians := List.push(Principal.fromText("iwnta-rdyti-ucuvq-j3ugn-ajdvd-o4c7b-7u7f3-xsfzp-rxbh6-fpbnk-sqe"), custodians);

  let CYCLE_AMOUNT : Nat = 1_000_000_000_000;
  let CKBTC_FEE : Nat = 10;
  let IS_PROD = true;
  stable var storage_canister_id : Text = "";
  //TODO: update when deploying on mainnet
  let main_ledger_principal = "mxzaz-hqaaa-aaaar-qaada-cai"; //ckBTC_ledger_principal
  //let main_ledger_principal = "bkmua-faaaa-aaaap-qbc3a-cai";
  var icrc_principal = "ryjl3-tyaaa-aaaaa-aaaba-cai";
  if (IS_PROD) {
    icrc_principal := main_ledger_principal;
    storage_canister_id := "5aui7-6qaaa-aaaap-qba2a-cai";
  };

  //// COLLECTIONS //////////////////////

  // public shared ({ caller }) func createEventNft(eventData : Event) : async Result.Result<Text, Text> {
  //   if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
  //     return #err("Not authorized");
  //   };

  //   let fuzz = Fuzz.Fuzz();
  //   let eventId = fuzz.text.randomAlphanumeric(16);
  //   Debug.print(debug_show (eventData));
  //   let event = {
  //     eventData with id = eventId;
  //     creationDate = Time.now();
  //     transactionId = 0;
  //   };
  //   Debug.print(debug_show (event));
  //   ignore Map.put(events, thash, eventId, event);
  //   ignore update_status(#update_cycle_balance);
  //   return #ok(eventId);
  // };

  // public shared ({ caller }) func getEvents() : async Result.Result<[Event], Text> {
  //   if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
  //     return #err("Not Authorized");
  //   };
  //   let iter = Map.vals<Text, Event>(events);
  //   return #ok(Iter.toArray(iter));
  // };

  // public query func getEvent(eventId : Text) : async Result.Result<Event, Text> {
  //   switch (Map.get(events, thash, eventId)) {
  //     case (?event) {
  //       return #ok(event);
  //     };
  //     case (null) {
  //       return #err("No such event");
  //     };
  //   };
  // };

  // public shared ({ caller }) func updateEventState(eventId : Text, newState : { #active; #ended; #inactive }) : async Result.Result<Text, Text> {
  //   if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
  //     return #err("Not Authorized");
  //   };
  //   switch (Map.get(events, thash, eventId)) {
  //     case (?event) {
  //       //ignore Map.remove(coupons, thash, couponId);
  //       Map.set(events, thash, eventId, { event with state = newState });
  //       return #ok("Event Updated");
  //     };
  //     case (null) {
  //       return #err("No event with this ID");
  //     };
  //   };
  // };

  // public shared ({ caller }) func claimEventNftToAddress(id : Text, to : Principal) : async Result.Result<Text, Text> {

  //   // get event metadata
  //   var nftName = "ERROR";
  //   var description = "ERROR";
  //   var nftType = "ERROR";
  //   var nftUrl = "ERROR";
  //   var eventId = "ERROR";
  //   var txId = 0;
  //   var eventState : { #active; #ended; #inactive } = #ended;
  //   switch (Map.get(events, thash, id)) {
  //     case (?event) {
  //       nftName := event.nftName;
  //       nftType := event.nftType;
  //       nftUrl := event.nftUrl;
  //       description := event.description;
  //       eventState := event.state;
  //       eventId := event.id;
  //       //TODO check timeframe

  //       switch (eventState) {
  //         case (#active) {
  //           // check if user has already redeemed
  //           let check = Map.get(eventsByPrincipal, pthash, (to, id));
  //           switch (check) {
  //             case (?exists) {
  //               return #err("Already redeemed");
  //             };
  //             case (null) {
  //               //update txid
  //               ignore Map.put(events, thash, eventId, { event with transactionId = event.transactionId + 1 });
  //               txId := event.transactionId + 1;

  //               let newId = Nat64.fromNat(List.size(nfts));
  //               let nft : Types.Nft = {
  //                 owner = to;
  //                 id = newId;
  //                 metadata = getEventMetadata(nftName, description, nftType, nftUrl, eventId, txId);
  //               };

  //               nfts := List.push(nft, nfts);

  //               transactionId += 1;
  //               ignore Map.put(eventsByPrincipal, pthash, (to, id), newId);
  //               return #ok(Nat64.toText(newId));
  //             };
  //           };
  //         };
  //         case (#ended) {
  //           return #err("The event is over");
  //         };
  //         case (#inactive) {
  //           return #err("The event hasn't started yet");
  //         };
  //       };
  //     };
  //     case (null) {
  //       return #err("No such event");
  //     };
  //   };
  // };

  // public shared ({ caller }) func claimEventNft(id : Text) : async Result.Result<Text, Text> {

  //   // get event metadata
  //   var nftName = "ERROR";
  //   var description = "ERROR";
  //   var nftType = "ERROR";
  //   var nftUrl = "ERROR";
  //   var eventId = "ERROR";
  //   var txId = 0;
  //   var eventState : { #active; #ended; #inactive } = #ended;
  //   switch (Map.get(events, thash, id)) {
  //     case (?event) {
  //       nftName := event.nftName;
  //       nftType := event.nftType;
  //       nftUrl := event.nftUrl;
  //       description := event.description;
  //       eventState := event.state;
  //       eventId := event.id;
  //       //TODO check timeframe

  //       switch (eventState) {
  //         case (#active) {
  //           // check if user has already redeemed
  //           let check = Map.get(eventsByPrincipal, pthash, (caller, id));
  //           switch (check) {
  //             case (?exists) {
  //               return #err("Already redeemed");
  //             };
  //             case (null) {
  //               //update txid
  //               ignore Map.put(events, thash, eventId, { event with transactionId = event.transactionId + 1 });
  //               txId := event.transactionId + 1;

  //               let newId = Nat64.fromNat(List.size(nfts));
  //               let nft : Types.Nft = {
  //                 owner = caller;
  //                 id = newId;
  //                 metadata = getEventMetadata(nftName, description, nftType, nftUrl, eventId, txId);
  //               };

  //               nfts := List.push(nft, nfts);

  //               transactionId += 1;
  //               ignore Map.put(eventsByPrincipal, pthash, (caller, id), newId);
  //               return #ok(Nat64.toText(newId));
  //             };
  //           };
  //         };
  //         case (#ended) {
  //           return #err("The event is over");
  //         };
  //         case (#inactive) {
  //           return #err("The event hasn't started yet");
  //         };
  //       };
  //     };
  //     case (null) {
  //       return #err("No such event");
  //     };
  //   };
  // };

  /////////////////ADMIN////////////////////////////////////

  public shared ({ caller }) func isCustodian() : async Bool {
    Debug.print(debug_show (caller));
    if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
      return false;
    };
    return true;
  };

  public shared ({ caller }) func addCustodian(new_custodian : Principal) : async Result.Result<Text, Text> {
    if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
      return #err("not custodian");
    };
    custodians := List.push(new_custodian, custodians);

    if (storage_canister_id != "") {
      let storage_canister : Types.StorageType = actor (storage_canister_id);
      ignore storage_canister.addCustodian(new_custodian);
    };
    return #ok("custodian");
  };

  type definite_canister_settings = {
    controllers : [Principal];
    compute_allocation : Nat;
    memory_allocation : Nat;
    freezing_threshold : Nat;
  };

  type canister_settings = {
    controllers : ?[Principal];
    compute_allocation : ?Nat;
    memory_allocation : ?Nat;
    freezing_threshold : ?Nat;
  };

  type ManagementCanisterActor = actor {
    canister_status : ({ canister_id : Principal }) -> async ({
      status : { #running; #stopping; #stopped };
      settings : definite_canister_settings;
      module_hash : ?Blob;
      memory_size : Nat;
      cycles : Nat;
      idle_cycles_burned_per_day : Nat;
    });

    update_settings : ({
      canister_id : Principal;
      settings : canister_settings;
    }) -> ();
  };

  stable var isCreating = false;
  type CreationError = {
    #notenoughcycles;
    #awaitingid;
  };

  public query func get_storage_canister_id() : async Result.Result<Text, { #awaitingid; #nostorageid }> {
    if (isCreating) return #err(#awaitingid);
    if (storage_canister_id == "" and not isCreating) {
      return #err(#nostorageid);
    };
    return #ok(storage_canister_id);

  };

  public query func get_ledger_canister_id() : async Text {
    return icrc_principal;
  };

  public shared ({ caller }) func setLedgerCanisterId(id : Principal) : async Result.Result<Text, Text> {
    if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
      return #err("Not Authorized");
    };
    icrc_principal := Principal.toText(id);
    return #ok(icrc_principal);
  };

  public shared ({ caller }) func create_storage_canister(isProd : Bool) : async Result.Result<Text, CreationError> {
    if (isCreating) return #err(#awaitingid);
    if (storage_canister_id == "" and not isCreating) {
      isCreating := true;
      let res = await create_file_storage_canister(isProd);
      isCreating := false;
      if (res) { return #ok(storage_canister_id) } else {
        return #err(#notenoughcycles);
      };
    };
    return #ok(storage_canister_id);

  };
  private func create_file_storage_canister(isProd : Bool) : async Bool {
    let balance = Cycles.balance();
    if (balance <= CYCLE_AMOUNT) return false;

    Cycles.add(CYCLE_AMOUNT);
    let file_storage_actor = await FileStorage.FileStorage(isProd);
    ignore file_storage_actor.addCustodians(custodians);
    let principal = Principal.fromActor(file_storage_actor);
    storage_canister_id := Principal.toText(principal);
    ignore add_controller_to_storage();
    return true;

  };

  private func add_controller_to_storage() : async () {
    let management_canister_actor : ManagementCanisterActor = actor ("aaaaa-aa");
    let principal = Principal.fromText(storage_canister_id);
    let res = await management_canister_actor.canister_status({
      canister_id = principal;
    });
    Debug.print(debug_show (res));
    let b = Buffer.Buffer<Principal>(1);
    var check = true;
    for (controller in res.settings.controllers.vals()) {
      b.add(controller);
      if (Principal.equal(controller, custodian)) {
        check := false;
      };
    };
    if (check) b.add(custodian);

    let new_controllers = Buffer.toArray(b);
    management_canister_actor.update_settings({
      canister_id = principal;
      settings = {
        controllers = ?new_controllers;
        compute_allocation = ?res.settings.compute_allocation;
        memory_allocation = ?res.settings.memory_allocation;
        freezing_threshold = ?res.settings.freezing_threshold;
      };
    });
  };

  public shared ({ caller }) func init_storage_controllers() : async Result.Result<Text, Text> {
    if (storage_canister_id == "") return #err("No storage canister");

    ignore add_controller_to_storage();
    return #ok("Done");
  };

  public shared ({ caller }) func set_storage_canister_id(id : Principal) : async Result.Result<Text, Text> {

    if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
      return #err("Not allowed");
    };

    if (not isCanisterPrincipal(id) or isAnonymous(id)) {
      return #err("invalid principal");
    };

    storage_canister_id := Principal.toText(id);
    return #ok("storage_canister_id set");
  };

  public shared ({ caller }) func set_ledger_canister_id(id : Principal) : async Result.Result<Text, Text> {

    if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
      return #err("Not allowed");
    };

    if (not isCanisterPrincipal(id) or isAnonymous(id)) {
      return #err("invalid principal");
    };

    icrc_principal := Principal.toText(id);
    return #ok("ledger_canister set");
  };

  type CanisterStatus = {
    nft_balance : Nat;
    nft_ledger_balance : Nat;
    outstanding_balance : Nat;
    storage_balance : Nat;
    storage_memory_used : Nat;
    storage_daily_burn : Nat;
    controllers : [Principal];
  };

  stable var canister_status : CanisterStatus = {
    nft_balance = Cycles.balance();
    nft_ledger_balance = 0;
    outstanding_balance = 0;
    storage_balance = 0;
    storage_memory_used = 0;
    storage_daily_burn = 0;
    controllers = [];
  };

  public query func get_status() : async CanisterStatus {
    return canister_status;
  };

  //todo check
  private func update_status(action : { #update_ledger_balance; #update_cycle_balance }) : async () {
    switch (action) {
      case (#update_ledger_balance) {
        let ledger_canister : ICRCTypes.RustTokenInterface = actor (icrc_principal);
        let balance = await ledger_canister.icrc1_balance_of({
          owner = Principal.fromActor(Self);
          subaccount = null;
        });

        canister_status := {
          canister_status with
          nft_ledger_balance = balance;
          outstanding_balance = outstandingCouponsBalance;
        };

      };
      case (#update_cycle_balance) {
        if (storage_canister_id == "") {
          canister_status := {
            canister_status with nft_balance = Cycles.balance();
          };
          return;
        };

        let management_canister_actor : ManagementCanisterActor = actor ("aaaaa-aa");
        let res = await management_canister_actor.canister_status({
          canister_id = Principal.fromText(storage_canister_id);
        });
        Debug.print(debug_show (res.settings.controllers));
        canister_status := {
          canister_status with
          nft_balance = Cycles.balance();
          outstanding_balance = outstandingCouponsBalance;
          storage_balance = res.cycles;
          storage_memory_used = res.memory_size;
          storage_daily_burn = res.idle_cycles_burned_per_day;
          controllers = res.settings.controllers;
        };
      };
    };

    return;
  };

  // func setTimerA() {
  //   ignore Timer.recurringTimer(
  //     #seconds(10 * 60 * 60),
  //     func() : async () {
  //       Debug.print("fired");
  //       await update_status();
  //     },
  //   );
  // };
  // setTimerA();

  private func isAnonymous(caller : Principal) : Bool {
    Principal.equal(caller, Principal.fromText("2vxsx-fae"));
  };

  private func isCanisterPrincipal(p : Principal) : Bool {
    let principal_text = Principal.toText(p);
    let correct_length = Text.size(principal_text) == 27;
    let correct_last_characters = Text.endsWith(principal_text, #text "-cai");

    if (Bool.logand(correct_length, correct_last_characters)) {
      return true;
    };
    return false;
  };

  //// COUPONS //////////////////////

  // public shared ({ caller }) func createCoupon(couponData : Coupon) : async Result.Result<Text, Text> {
  //   if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
  //     return #err("Not authorized");
  //   };

  //   if (couponData.amount <= 0) return #err("Invalid Amount");

  //   let ledger_canister : ICRCTypes.TokenInterface = actor (icrc_principal);
  //   let balance = await ledger_canister.icrc1_balance_of({
  //     owner = Principal.fromActor(Self);
  //     subaccount = null;
  //   });

  //   if (balance < couponData.amount + CKBTC_FEE + outstandingCouponsBalance) return #err("Not enough balance");

  //   outstandingCouponsBalance := outstandingCouponsBalance + couponData.amount + CKBTC_FEE;
  //   canister_status := {
  //     canister_status with
  //     nft_ledger_balance = balance;
  //     outstanding_balance = outstandingCouponsBalance;
  //   };

  //   let fuzz = Fuzz.Fuzz();
  //   let couponId = fuzz.text.randomAlphanumeric(16);
  //   Debug.print(debug_show (couponData));
  //   Debug.print(debug_show (outstandingCouponsBalance));
  //   ignore Map.put(coupons, thash, couponId, { couponData with id = couponId });

  //   return #ok(couponId);
  // };

  // public shared ({ caller }) func getCoupons() : async Result.Result<[Coupon], Text> {
  //   if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
  //     return #err("Not Authorized");
  //   };
  //   let iter = Map.vals<Text, Coupon>(coupons);
  //   return #ok(Iter.toArray(iter));
  // };

  // public query func getCoupon(couponId : Text) : async Result.Result<Coupon, Text> {
  //   switch (Map.get(coupons, thash, couponId)) {
  //     case (?coupon) {
  //       return #ok(coupon);
  //     };
  //     case (null) {
  //       return #err("No such coupon");
  //     };
  //   };
  // };

  // private func changeCouponState(couponId : Text, redeemer : ?Principal, newState : { #redeemed; #active }) : Result.Result<Text, Text> {
  //   switch (Map.get(coupons, thash, couponId)) {
  //     case (?coupon) {
  //       ignore Map.put(coupons, thash, couponId, { coupon with state = newState; redeemer = redeemer });
  //       return #ok("state changed");
  //     };
  //     case (null) {
  //       return #err("No such coupon");
  //     };
  //   };
  // };

  // private func redeemCouponInternal(couponId : Text, redeemer : Principal) : async Result.Result<Text, Text> {
  //   if (isAnonymous(caller)) return #err("For your safety you can't withdraw to an anonymous principal, login first");
  //   var amount = 0;
  //   switch (Map.get(coupons, thash, couponId)) {
  //     case (?coupon) {
  //       if (coupon.state == #frozen) return #err("Coupon is frozen and can't be redeemed");
  //       if (coupon.state == #redeemed) return #err("Coupon has already been redeemed");
  //       //This is done to prevent multiple users from redeeming same coupon due to icrc1_transfer being an async and possibly cross subnet call
  //       ignore Map.put(coupons, thash, couponId, { coupon with state = #redeemed; redeemer = ?redeemer });
  //       amount := coupon.amount;
  //     };
  //     case (null) {
  //       return #err("No such coupon");
  //     };
  //   };
  //   //TODO check timeframe

  //   //ledger transfer
  //   //for whatever reason Motoko uses #ok instead of #Ok for variants so return type changes based on how the icrc1 canister is implemented
  //   // fix correctly by updating ICRC1 motoko ledger
  //   if (Text.equal(icrc_principal, "mxzaz-hqaaa-aaaar-qaada-cai")) {
  //     let ledger_canister : ICRCTypes.RustTokenInterface = actor (icrc_principal);
  //     let res = await ledger_canister.icrc1_transfer({
  //       to = { owner = redeemer; subaccount = null };
  //       fee = ?CKBTC_FEE;
  //       memo = null;
  //       from_subaccount = null;
  //       created_at_time = null;
  //       amount = amount //decimals
  //     });
  //     Debug.print(debug_show (res));
  //     switch (res) {
  //       case (#Ok(n)) {
  //         outstandingCouponsBalance := outstandingCouponsBalance - amount - CKBTC_FEE;
  //         ignore update_status(#update_ledger_balance);
  //         switch (Map.get(coupons, thash, couponId)) {
  //           case (?coupon) {
  //             //ignore Map.put(coupons, thash, couponId, { coupon with state = #redeemed; redeemer = ?redeemer });
  //           };
  //           case (null) {
  //             return #err("No such coupon");
  //           };
  //         };
  //         return #ok("Success! check your wallet");
  //       };
  //       case (#Err(#GenericError(e))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error GenericError!");
  //       };
  //       case (#Err(#TemporarilyUnavailable(e))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error TemporarilyUnavailable!");
  //       };
  //       case (#Err(#BadBurn(e))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error BadBurn!");
  //       };
  //       case (#Err(#Duplicate(e))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error Duplicate!");
  //       };
  //       case (#Err(#BadFee(e))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error BadFee!");
  //       };
  //       case (#Err(#CreatedInFuture(e))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error CreatedInFuture!");
  //       };
  //       case (#Err(#TooOld(e))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error TooOld!");
  //       };
  //       case (#Err(#InsufficientFunds(balance))) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error InsufficientFunds! ");
  //       };
  //       case (#Err(_)) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error redeeming!");
  //       };
  //     };

  //   } else {
  //     let ledger_canister = actor (icrc_principal) : ICRCTypes.TokenInterface;
  //     let res = await ledger_canister.icrc1_transfer({
  //       to = { owner = redeemer; subaccount = null };
  //       fee = ?CKBTC_FEE;
  //       memo = null;
  //       from_subaccount = null;
  //       created_at_time = null;
  //       amount = amount //decimals
  //     });
  //     Debug.print(debug_show (res));
  //     switch (res) {
  //       case (#ok(n)) {
  //         outstandingCouponsBalance := outstandingCouponsBalance - amount - CKBTC_FEE;
  //         ignore update_status(#update_ledger_balance);
  //         switch (Map.get(coupons, thash, couponId)) {
  //           case (?coupon) {
  //             //ignore Map.put(coupons, thash, couponId, { coupon with state = #redeemed; redeemer = ?redeemer });
  //           };
  //           case (null) {
  //             return #err("No such coupon");
  //           };
  //         };
  //         return #ok("Success! check your wallet");
  //       };
  //       case (#err(_)) {
  //         ignore changeCouponState(couponId, null, #active);
  //         return #err("Error!");
  //       };
  //     };
  //   };
  // };

  // public shared ({ caller }) func redeemCoupon(couponId : Text) : async Result.Result<Text, Text> {
  //   return await redeemCouponInternal(couponId, caller);
  // };

  // public shared ({ caller }) func redeemCouponToPrincipal(couponId : Text, principal : Principal) : async Result.Result<Text, Text> {
  //   return await redeemCouponInternal(couponId, principal);
  // };

  // public shared ({ caller }) func updateCouponState(couponId : Text, newState : { #active; #frozen }) : async Result.Result<Text, Text> {
  //   if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
  //     return #err("Not Authorized");
  //   };
  //   switch (Map.get(coupons, thash, couponId)) {
  //     case (?coupon) {
  //       if (coupon.state == #redeemed) return #err("Coupon has already been redeemed");

  //       ignore Map.remove(coupons, thash, couponId);
  //       ignore Map.put(coupons, thash, couponId, { coupon with state = newState });
  //       return #ok("Coupon Updated");
  //     };
  //     case (null) {
  //       return #err("No coupon with this ID");
  //     };
  //   };
  // };

  // public shared ({ caller }) func deleteCoupon(couponId : Text) : async Result.Result<Text, Text> {
  //   if (not List.some(custodians, func(custodian : Principal) : Bool { custodian == caller })) {
  //     return #err("Not Authorized");
  //   };
  //   switch (Map.get(coupons, thash, couponId)) {
  //     case (?coupon) {
  //       if (coupon.state == #redeemed) return #err("Coupon has already been redeemed");

  //       ignore Map.remove(coupons, thash, couponId);
  //       outstandingCouponsBalance := outstandingCouponsBalance - coupon.amount - CKBTC_FEE;
  //       canister_status := {
  //         canister_status with
  //         outstanding_balance = outstandingCouponsBalance;
  //       };
  //       return #ok("Coupon Deleted");
  //     };
  //     case (null) {
  //       return #err("No coupon with this ID");
  //     };
  //   };
  // };
};
