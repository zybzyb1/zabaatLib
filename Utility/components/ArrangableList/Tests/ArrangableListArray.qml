import QtQuick 2.5
import QtQuick.Controls 1.4
import Zabaat.Utility 1.0 //get underscore!
Item {
    id : rootObject
    property alias model                        : logic.model
    property var   filterFunc
    property alias lv                           : lv
    property alias logic                        : logic
    property alias gui                          : gui

    property var   selectionDelegate             : selectionDelegate
    property color selectionDelegateDefaultColor : "green"
    property var   highlightDelegate             : rootObject.selectionDelegate //will normally just change by changing selectionDelegate!
    property var   delegate                      : simpleDelegate
    property real  delegateCellHeight            : lv.height * 0.1
    property var   blankDelegate                 : blankDelegate

//    readonly property int count_Original        : zsubOrig.sourceModel ?  zsubOrig.sourceModel.count : -1
//    readonly property alias count_ZSubOrignal   : zsubOrig.count
//    readonly property alias count_ZSubChanger   : zsubChanger.count
//    readonly property alias subModel            : zsubChanger  //for deprecated suppoert
//    readonly property alias subModelOrig        : zsubOrig


    readonly property var undo                  : logic.undo
    readonly property var redo                  : logic.redo
    readonly property var deselect              : logic.deselect
    readonly property var select                : logic.select
    readonly property var selectAll             : logic.selectAll
    readonly property var deselectAll           : logic.deselectAll
    readonly property var moveSelectedTo        : logic.moveSelectedTo
    readonly property var resetState            : logic.resetState

    readonly property alias indexList           : logic.indexList
    readonly property alias indexListFiltered   : logic.indexListFiltered


    onFilterFuncChanged:  {
        logic.lastTouchedIdx = -1;
        logic.deselectAll()
        logic.updateFiltered()
    }


    QtObject {
        id : logic
        property var model
        property var indexList
        property var indexListFiltered
        onModelChanged:  {
//            console.log("model is now" , model)
            logic.resetState();
            if(model) {
                logic.indexList = _.keys(model)    //get all the indices
            }
        }
        property bool indexListLock : false
        onIndexListChanged: {
//            console.log("INDEXLISt=", indexList)
//            logic.resetState();
//            console.log("-----------")
//            console.log("INDEXLIST =", JSON.stringify(indexList))
//            console.trace()
            logic.lastTouchedIdx = -1;
            logic.deselectAll()

//            logic.updateIndexListFiltered();
            if(!indexListLock && indexList && indexList.length > 0) {
                addToStates(indexList)
            }
//                logic.states.push(_.clone(indexList))
            updateFiltered();
        }
        onIndexListFilteredChanged: {
            logic.lastTouchedIdx = -1;
            logic.deselectAll()
        }


        function updateFiltered() {
            if(typeof filterFunc === 'function') {
                logic.indexListFiltered = _.filter(logic.indexList, function(a) {  //filter on the value (a is the index!)
                    return filterFunc(model[indexList[a]])
                }).sort(function(a,b){ return a- b} )
//                console.log("update filtered!!??")
            }
            else
                indexListFiltered = _.clone(indexList).sort(function(a,b){ return a- b} )

        }

        function addToStates(arr) {
            var s = states
            if(s === null || s === undefined)
                s = []
            if(s.length > 0)
                s.length = stateIdx + 1    //this will kill everything after the stateIdx

            arr = arr  || indexList
            if(arr) {
                s.push(_.clone(arr))
                stateIdx = s.length -1
            }
            states = s
        }



        //the display model is what gets shown. we can make changes to the ordering etc of this thing
                                    //the values this array holds are indicies (to model). So this is like a pointer array!
//        onDisplayModelChanged: if(modelFiltered) {
//                                   if(!logic.states)
//                                       logic.states = []

////                                   logic.states.push(_.clone(displayModel))
//                               }


        property var states         : []
//        onStatesChanged:{
//            console.log("@@@@@@@@@@@@@@@@@@")
//            console.log(JSON.stringify(states))
//            console.trace()
//        }

        property int stateIdx       : 0   //left of stateIdx is undos, right of stateIdx is redos.
//        onStateIdxChanged: console.log("IDX", stateIdx)

        property var selected       : ({})
        property int selectedLen    : 0
        property int lastTouchedIdx : -1



        function resetState(){
            logic.lastTouchedIdx = -1;
            logic.stateIdx = 0;
            logic.states   = [];
        }
        function isSelected(idx){
            return selected && selected[idx] !== undefined ?  true : false
        }

        function undos(){
            //get everything left of stateIdx
            var arr = []
            for(var i = 0; i < stateIdx; ++i){
                arr.push(states[i])
            }
//            console.log(JSON.stringify(arr,null,2))
            return arr;
        }
        function redos(){
            var arr = []
            for(var i = stateIdx  + 1; i < states.length; ++i){
                arr.push(states[i])
            }
            return arr;
        }
        function isArray(obj){
            return toString.call(obj) === '[object Array]';
        }
        function indexOf(arr, element){
            if(arr === null || arr === undefined || !isArray(arr))
                return -1;

            return _.indexOf(arr,element);
        }
        function moveArrayElem(arr, old_index, new_index) {
           if (new_index >= arr.length) {
               var k = new_index - arr.length;
               while ((k--) + 1) {
                   arr.push(undefined);
               }
           }
           arr.splice(new_index, 0, arr.splice(old_index, 1)[0]);
           return arr; // for testing purposes
       }

        function deselect(idx, ctrlMod){    //shiftMod don't matta here
            if(idx < 0 || idx >= indexListFiltered.length || indexOf(selected, idx) !== -1)
                return false;

            if(ctrlMod || selectedLen === 1){
                var ns = selected
                if(typeof ns[idx] !== 'undefined'){
                    delete ns[idx]

                    selected = ns
                    selectedLen--
                    return true;
                }
            }
            else {
               //actually, since ctrl wasn't pressed, we REALLY meant to select this
               //and deselect everything else
               return select(idx);
            }
        }
        function select(idx, ctrlMod, shiftMod){
            var failed = false;
            if(isArray(idx)){
//                console.log(idx)
                var newSelection = {}
                _.each(idx, function(v){
                    if(v < 0 || v >= indexListFiltered.length)
                        return failed = true;

                    newSelection[v] = indexListFiltered[v]
                })

                if(failed)
                    return false;

                selected    = newSelection
                selectedLen = idx.length;
                return true;
            }



            if(idx < 0 || idx >= indexListFiltered.length || indexOf(selected, idx) !== -1)
                return false;


            if(shiftMod) {  //this trumps ctrlMod & other types of clickers

                newSelection = {}
                if(logic.lastTouchedIdx !== -1){
                    //let's see if we need to go up for our selection or down
                    var start, end
                    if(idx < logic.lastTouchedIdx) {
                        start = idx
                        end = logic.lastTouchedIdx
                    }
                    else if(idx > logic.lastTouchedIdx){
                        start = logic.lastTouchedIdx
                        end = idx
                    }
                    else {
                        //both the same index, make sure we only select this thing
                        newSelection[logic.lastTouchedIdx] = indexListFiltered[logic.lastTouchedIdx]
                        selected = newSelection;
                        selectedLen = 1;
                        return true;
                    }


                    var count = end - start + 1;
                    for(var i = start; i <= end; ++i){
                        newSelection[i] = indexListFiltered[i]
                    }
                    selected = newSelection;
                    selectedLen = count;
                    return true;
                }
                else {
                    return false;
                }
            }
            else {
                newSelection = ctrlMod && selected ? selected : {};
                newSelection[idx] = indexListFiltered[idx];

                selected = newSelection;
                selectedLen = ctrlMod ? selectedLen + 1 : 1
            }

            return true;
        }
        function isUndef(item){
            return item === null || typeof item === 'undefined'
        }
        function undo(){
            if(states.length > 0 && stateIdx > 0){

                indexListLock = true;

                stateIdx--
                var undoState = states[stateIdx]
                indexList = undoState
                deselectAll()
//                refreshView(indexList)

                indexListLock = false;
            }
        }
        function redo(){
            if(states.length > 0 && stateIdx < states.length - 1) {

                indexListLock = true;

                stateIdx++
                var redoState = states[stateIdx]
                indexList = redoState
                deselectAll()
//                refreshView(indexList)

                indexListLock = false;
            }
        }
        function selectAll(){
            var ns = {}

            _.each(indexListFiltered, function(v,k){
                ns[k] = v
            })

            selected = ns
            selectedLen = indexListFiltered.length
        }
        function deselectAll(){
            selected = {}
            selectedLen = 0
        }
        function moveSelectedTo(idx , destIdx){     //destIdx is normally BLANK! HARD CODE, USE @ UR OWN RISK!
            if(selected && selectedLen > 0){

                var list         = logic.indexList
                var filteredList = logic.indexListFiltered

                var len   = filteredList.length
                var begin = filteredList[0]        //the refIdx at the start of our list(zsubChanger)
                var end   = filteredList[len -1]
//                var superBegin = zsubOrig.indexList[0]
//                var superEnd   = zsubOrig.indexList[zsubOrig.indexList.length - 1]
                var dest  = !isUndef(destIdx) ? destIdx :
                                                idx <= 0 ? begin : idx >= len ? end : filteredList[idx]

                if(selectedLen === 1){
                    //we only have one element. So this should be essy.
                    var s = selectedFirst();

                    //we dont actually have to move here. we can literally just swap the indices and it should be k.
//                    console.log("swap", s , "and", dest)
//                    console.log("swap", indexList[s] , "and", indexList[dest])
                    var tmp = list[dest]
                    list[dest] = list[s];
                    list[s]    = tmp;

                    deselectAll()
                    logic.lastTouchedIdx = -1;

                    logic.indexList = list

                }
                else {
                    //We have a list and selection in it, we want to move the selection to an
                    //index in the selection (idx). This is a relatively simple problem but what
                    //makes it tougher is that we need to move stuff in zsubOrig.indexList ,
                    //not the zsubChanger.indexList. And what makes this part harder is because of the filter
                    //function. The subChanger doesn't always have the entire list visible to it.

                    //step 1, rip out the selection array from the list
//                    var il    = cloneArr(zsubOrig.indexList)
                    dest = isUndef(destIdx) ? filteredList[idx] : logic.indexList[destIdx]
//                    console.log("dest idx is",dest, "SELECTED:", JSON.stringify(selected))
                    var movingArr = []
                    var sar       = []

                    _.each(selected, function(v,k){
                        sar[k] = v
                        movingArr[k] = logic.indexList[v]
                    })

                    sar = _.compact(sar);
                    movingArr = _.compact(movingArr);

//                    console.log("sar      ", sar)
//                    console.log("movingArr", movingArr)
                    //we need the SAR array (to figure out our head & tail), essentially to figure out
                    //if we are moving up or down.
                    var difference = _.difference(logic.indexList, movingArr);
//                    console.log("remove", movingArr, "from", zsubOrig.indexList , "=", il)


                    //Figure out the head, tail
                    var head   = _.first(sar)
                    var tail   = _.last(sar)
                    destIdx    = _.indexOf(difference, logic.indexList[dest]) //indexOf(il, ptrList[dest])

//                    console.log("move to", destIdx)

//                    console.log("H:",head, "T:",tail, "\t\tDest:", dest, "@", destIdx)
                    //Subdivide the ilArr further @ dest.
                    //Place movingArr on left or right of it , depending on special conditions.
//                    console.log("move", movingArr, "to", destIdx)
                    if(destIdx !== -1){
                        var left, right

                        if(head > dest) { //moving stuff up
//                            console.log("moving stuff up")
                            if(difference.length === 1){
                                left = []
                                right = difference;
                            }
                            else {
                                left = difference.slice(0, destIdx);
                                right = difference.slice(destIdx, difference.length);
                            }
//                            return console.log(left, movingArr, right)
                        }
                        else if(head < dest){    //moving stuff down
//                            console.log("moving stuff down")
                            if(tail < dest || difference.length === 1){
//                                console.log("case 1::\ttail<dest (", tail , "<", dest ,")"  , il)
                                left  = difference
                                right = []
                            }
                            else {
//                                console.log("case 2")
                                left = difference.slice(0, destIdx);
                                right = difference.slice(destIdx, difference.length);
                            }
                        }
                        else {
//                            console.log("head & dest are the same" , head , "===" , dest)
                            return;
                        }


//                        console.log(left, movingArr, right)
                        difference = left.concat(movingArr).concat(right)
////                        select(newArray(dest, dest + selectedLen - 1))
                        logic.indexList = difference;
                        deselectAll()
                        logic.lastTouchedIdx = -1;
                    }

                }

                //remove everything after stateIdx (if not last)
                //by virtue of changing the index list, it should automatically add it to our states
//                addToStates();

            }
        }
        function selectedFirst(){
            if(selected){
                for(var s in selected)
                    return selected[s]
            }
            return null;
        }



    }
    Item {
        id : gui
        anchors.fill: parent
        Component.onCompleted: gui.forceActiveFocus()
        property bool ctrlModifier : false
        property bool shiftModifier : false

        Keys.onPressed: {
            if(event.modifiers & Qt.ControlModifier)
                ctrlModifier = true;
            if(event.modifiers & Qt.ShiftModifier)
                shiftModifier = true;
        }
        Keys.onReleased: {
            if(!event.modifiers)
                return ctrlModifier = shiftModifier = false;

            var s = false;
            var c = false;
            if(event.modifiers & Qt.ShiftModifier){
                 s = true;
            }

            if(event.modifiers & Qt.ControlModifier){
              c = true;
            }
            ctrlModifier = c;
            shiftModifier = s;

            if((ctrlModifier && shiftModifier && event.key === Qt.Key_Z) ||
                    (ctrlModifier && event.key === Qt.Key_Y)) {
                logic.redo()
            }
            else if(ctrlModifier && event.key === Qt.Key_Z){
                logic.undo()
            }
        }

        ScrollView {
            anchors.fill: parent
            ListView {
                id : lv
                anchors.fill: parent
                model : logic.indexListFiltered
                delegate: Loader {
                    id : delegateLoader
                    width : lv.width
                    height : delegateCellHeight
                    sourceComponent : dragDelegate.index !== index ? rootObject.delegate : rootObject.blankDelegate
//                    Component.onCompleted: console.log(index)

                    property int _index : index
                    property bool imADelegate : true
                    property bool selected : logic.isSelected(index) ? true : false

                    onLoaded :  {
                        item.anchors.fill = delegateLoader
                        if(item.hasOwnProperty('model'))    item.model = Qt.binding(function() { return logic.model[logic.indexList[modelData]] })
                        if(item.hasOwnProperty('index'))    item.index = Qt.binding(function() { return index;    })
                    }

                    Loader {
                        anchors.fill   : parent
                        sourceComponent: parent.selected && !dMsArea.isDragging ? rootObject.selectionDelegate : null
                        z : 9
                    }
                    DropArea {
                        id : dDropArea
                        anchors.fill: parent
                        objectName : "DropArea:" + parent._index
                        keys : ["dropItem"]
                        z : 999

                        onEntered: delHighlightLoader.sourceComponent = rootObject.highlightDelegate//dBorderRect.border.width = rootObject.delegateHighlightThickness
                        onExited : delHighlightLoader.sourceComponent = null; //dBorderRect.border.width  = 0;


                        Loader {
                            id : delHighlightLoader
                            anchors.fill: parent
                        }

                    }
                }

                MouseArea {
                    id : dMsArea
                    anchors.fill: parent
                    propagateComposedEvents: true
                    preventStealing: false
                    drag.target: dragDelegate
                    onClicked: {
                        gui.forceActiveFocus()
                        var idx = lv.indexAt(mouseX, mouseY + lv.contentY)
                        if(idx !== -1){
                            if(!gui.ctrlModifier && !gui.shiftModifier)
                                logic.lastTouchedIdx = idx;

                            return logic.selected && typeof logic.selected[idx] !== 'undefined' ? logic.deselect(idx, gui.ctrlModifier, gui.shiftModifier) :
                                                                                                  logic.select(idx  , gui.ctrlModifier, gui.shiftModifier);
                        }
                    }

                    property bool isDragging : drag.active
                    onIsDraggingChanged: {
                        if(!isDragging){
                            var dTarget = dragDelegate.Drag.target
                            if(dTarget){
                                var idx = dTarget.parent._index
                                if(idx > -1 && idx < logic.indexListFiltered.length){
                                    logic.moveSelectedTo(idx);
                                }
                            }
                            dragDelegate.index= -1;
                        }
                        else {
                            idx = lv.indexAt(mouseX, mouseY + lv.contentY)
                            if(idx !== -1){
                                dragDelegate.index = idx
                                if(!logic.isSelected(idx)) {
                                    logic.select(idx, true);
                                }
                            }
                        }
                    }


                }
                Loader {
                    id : dragDelegate
                    width : logic.selectedLen > 1 ? lv.width - height : lv.width
                    height : delegateCellHeight
                    sourceComponent: index !== -1  ? rootObject.delegate : null
                    property int index : -1
                    x : dMsArea.mouseX - width/2
                    y : dMsArea.mouseY - height/2
                    onLoaded : {
                        item.anchors.fill = dragDelegate
                        if(item.hasOwnProperty('model'))
                            item.model = Qt.binding(function() { return model[index] })
                        if(item.hasOwnProperty('index'))
                            item.index = Qt.binding(function() { return index; })
                    }

                    Drag.keys: ["dropItem"]
                    Drag.active: dMsArea.isDragging
                    Drag.hotSpot.x : width/2
                    Drag.hotSpot.y : height/2

                    Rectangle {
                        anchors.left: parent.right
                        width : parent.height
                        height : parent.height
                        radius : height/2
                        color  : "red"
                        visible : logic.selectedLen > 1 && dragDelegate.sourceComponent !== null
                        border.width: 1
                        Text{
                            anchors.fill: parent
                            font.pixelSize: height * 1/2
                            color : 'white'
                            text  : logic.selectedLen
                            scale : paintedWidth > width ? width / paintedWidth : 1
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                }




                function getDelegateInstance(idx){
                    for(var i = 0; i < lv.contentItem.children.length; ++i) {
                        var child = lv.contentItem.children[i]
                        if(child && child.imADelegate && child._index === idx)
                            return child;
                    }
                    return null;
                }
            }
        }


    }



    Component {
        id : blankDelegate
        Rectangle {
            border.width: 1
            color : 'transparent'
        }
    }
    Component {
        id : simpleDelegate
        Rectangle {
            border.width: 1
            property int index
            property var model
            Text {
                anchors.fill: parent
                font.pixelSize: height * 1/3
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
//                    text             : parent.model ? JSON.stringify(parent.model) : "N/A"
                text : typeof parent.model === 'string' ? parent.model : "x_x"
//                onTextChanged: console.log(text)
            }
        }
    }
    Component {
        id : selectionDelegate
        Rectangle {
            color : selectionDelegateDefaultColor
            opacity : 0.5
        }
    }


}