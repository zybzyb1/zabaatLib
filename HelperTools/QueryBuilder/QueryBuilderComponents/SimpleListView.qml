import QtQuick 2.5
Repeater {
    id : rootObject;
    property int spacing
    property int contentHeight
    property int minHeight
    height : Math.max(contentHeight, minHeight);

    onCountChanged: evalYs();


//    onTChanged: evalYs();
//    readonly property real t : anchors.topMargin;


    function evalYs(trigger) {
        if(count <= 0)
            return;

//        console.log("EVALUTATING YS on account of", trigger, ". There are", count , "items");

        var runningY = 0;
        for(var i = 0; i < count; ++i) {
            var item = itemAt(i);
            if(item) {
            //this line was not performant!! We dont need it in this case anyway since we reload the entire model
            //item.heightChanged.connect(function() { console.log("HCHG"); evalYs(); });
                item.anchors.top       = rootObject.top;
                item.anchors.topMargin = i === 0 ? 0 : runningY;
                runningY               += item.height + spacing;
            }
        }
        //since we added one xtra at the end and margin really isn't part of it
        contentHeight = (runningY - spacing);
//        console.log("FINISHED EVAL. This is what we got", contentHeight, rootObject.anchors.topMargin);
    }





}
