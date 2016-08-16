import QtTest 1.0
import QtQuick 2.0
import Zabaat.MVVM 1.0
import Zabaat.Utility 1.0
import Zabaat.Testing 1.0
ZabaatTest {
    id : rootObject
    objectName : "RESTFULArray"
    testObj : RESTFULArray{
        id : ra
    }

    property var defaultObj : [
        { id : "0", name : "Shahan", hobbies : [{id:100,name:'fencing'}] } ,
        { id : "1", name : "Fahad" , hobbies : [{id:101,name:'dancing'}] }
    ]


    function init() {
        ra.reset();
        clearSignals();
        defaultObj = [
                    { id : "0", name : "Shahan", hobbies : [{id:100,name:'fencing'}] } ,
                    { id : "1", name : "Fahad" , hobbies : [{id:101,name:'dancing'}] }
                ]

    }

    function cleanup(){
        clearSignals()
    }


    //test if runUpdate works as an init!
    function test_01_runUpdate_init(){
        ra.runUpdate(defaultObj)

        compare(ra.arr.length, 2 , "arr length should be 2")
        compare(ra.length, 2, "ra arr length should be 2")
        compare(ra.arr[0].id, "0", "first one should be 0")
        compare(ra.arr[1].id, "1", "first one should be 1")
        compare(ra.priv.idMap["0"] , defaultObj[0])
        compare(ra.priv.idMap["1"] , defaultObj[1])
        compare(toString.call(signals.created), '[object Array]' , "Should have generated created signals!")
        compare(signals.created.length, 2, "There should be 2 created signals")

    }

    //test if reset works after we have some items!
    function test_02_reset() {
        ra.runUpdate(defaultObj)
        clearSignals();

        ra.reset()
        compare(ra.arr, undefined, "arr length should be undefined")
        compare(ra.length, 0, "ra arr length should be 0")
        compare(toString.call(signals.deleted),'[object Array]', "Should have generated deleted signals!")
        compare(signals.deleted.length, 2, "There should be 2 created signals")
    }


    function test_03_getRoot_existing(){
        ra.runUpdate(defaultObj)

        var item = ra.get("0")
        compare(item, defaultObj[0])
        compare(item, ra.arr[0], "should be both pointers to the same object!")
    }

    function test_04_getRoot_nonexisting(){
        ra.runUpdate(defaultObj)

        var item = ra.get("2")
        compare(item, undefined)
    }

    function test_05_getInner_existing() {
        ra.runUpdate(defaultObj);

        compare(ra.get("0/name"), 'Shahan')
        compare(ra.get("1/name"), 'Fahad')
    }

    function test_06_getInner_existing_nonbasic() {
        ra.runUpdate(defaultObj);

        compare(ra.get("0/hobbies")    , defaultObj[0].hobbies   , "0/hobbies mismatch")
        compare(ra.get("0/hobbies/100"), defaultObj[0].hobbies[0], "0/hobbies/100 mismatch")
        compare(ra.get("0/hobbies/100/name"), "fencing", "0/hobbies/100/name mismatch")

        compare(ra.get("1/hobbies"), defaultObj[1].hobbies, "1/hobbies mismatch")
        compare(ra.get("1/hobbies/101"), defaultObj[1].hobbies[0] , "1/hobbies/101 mismatch")
        compare(ra.get("1/hobbies/101/name"), "dancing", "1/hobbies/101/name mismatch")
    }

    function test_07_getInner_nonexisting_nonbasic() {
        ra.runUpdate(defaultObj);

        compare(ra.get("0/hobbies/0"), undefined , "0/hobbies/0 mismatch")
        compare(ra.get("0/hobbies/1"), undefined , "0/hobbies/1 mismatch")
    }

    function test_08_setRoot_nonexisting() {
        var obj = { name : "Shahan" }
        ra.set("2" , obj)

        var item = ra.get("2")

        compare(ra.length, 1, "ra arr length should be 1")
        compare(ra.arr.length, 1 , "arr length should be 1")
        compare(ra.arr[0].id, "2", "first one's id should be 2")
        compare(ra.priv.idMap["2"], obj, "id 2 should be the same as obj!")
        compare(toString.call(signals.created), '[object Array]' , "Should have generated created signals!")
        compare(signals.created.length, 3, "There should be 3 created signals, [2,2/name,2/id]")

        var rc = _.reduce(signals.created, function(a,e){
            a[e[0]] = true;
            return a;
        },{})

        compare(rc["2"]     , true)
        compare(rc["2/name"], true)
        compare(rc["2/id"]  , true)
        compare(item, obj);
    }

    function test_08b_setRoot_nonexisting() {
        ra.set("2/name" , "Wolf")

        var item = ra.get("2")


        compare(ra.length, 1, "ra arr length should be 1")
        compare(ra.arr.length, 1 , "arr length should be 1")
        compare(ra.arr[0].id, "2", "first one's id should be 2")
        compare(ra.priv.idMap["2"].name, "Wolf", "Should have name wolf!")
        compare(toString.call(signals.created), '[object Array]' , "Should have generated created signals!")
        compare(signals.created.length, 2, "There should be 2 created signals")

        var rc = _.reduce(signals.created, function(a,e){
            a[e[0]] = true;
            return a;
        },{})

        compare(rc["2"] , true);
        compare(rc["2/name"],true);
    }

    function test_09_setRoot_existing() {
        ra.runUpdate(defaultObj);

        ra.set("0",{name : "Wolf"})
        compare(ra.get("0/name"), "Wolf")
        compare(ra.priv.idMap["0"].name , "Wolf")
    }

    function test_10_setDeeper_existingSimple(){
        ra.runUpdate(defaultObj);

        ra.set("0/hobbies/100/name", "cherping" )
        compare(ra.get("0/hobbies/100/name"), "cherping")
    }

    function test_10_setDeeper_existingComplex(){
        ra.runUpdate(defaultObj);

        ra.set("0/hobbies/100", { level : "9000+" } )
        compare(ra.get("0/hobbies/100/level"), "9000+")
    }

    function test_11_deleteRoot() {
        ra.runUpdate(defaultObj);

        ra.del("0")
        compare(ra.length, 1);
        compare(ra.arr.length , 1);



        var rc = _.reduce(signals.deleted, function(a,e){
            a[e[0]] = true;
            return a;
        },{})

        compare(rc["0"], true)
        compare(rc["0/id"], true)
        compare(rc["0/name"], true)
        compare(rc["0/hobbies"], true)
        compare(rc["0/hobbies/100"], true)
        compare(rc["0/hobbies/100/id"], true)
        compare(rc["0/hobbies/100/name"], true)

        compare(signals.deleted.length, 7);
    }

    function test_12_deleteExisting() {
        ra.runUpdate(defaultObj);
        ra.del("0/hobbies/100")

        compare(ra.length, 2);
        compare(ra.arr.length , 2);
        compare(ra.get("0/hobbies").length, 0)

        var rc = _.reduce(signals.deleted, function(a,e){
            a[e[0]] = true;
            return a;
        },{})

        compare(rc["0/hobbies/100"], true)
        compare(rc["0/hobbies/100/id"], true)
        compare(rc["0/hobbies/100/name"], true)
        compare(signals.deleted.length, 3);
    }

    function test_13_deleteRootNonExisting() {
        ra.runUpdate(defaultObj);

        ra.del("2")

        compare(ra.length, 2);
        compare(ra.arr.length , 2);
        compare(signals.deleted.length, 0);
    }

    function test_14_deleteDeeper_NonExisting() {
        ra.runUpdate(defaultObj);

        ra.del("0/hobbies/0")
        compare(ra.length, 2);
        compare(ra.arr.length , 2);
        compare(ra.get("0/hobbies").length, 1)
        compare(signals.deleted.length, 0);
    }




}