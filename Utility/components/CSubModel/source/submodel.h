#ifndef SUBMODEL_H
#define SUBMODEL_H

#include <QObject>
#include <QDebug>
#include <QAbstractListModel>
#include <QJSValue>
#include <QJSValueList>
#include <vector>
#include <QList>
#include <QStringList>
#include "mstimer.h"
#include "nanotimer.h"

#include <QQmlListProperty>

typedef QHash<int,QByteArray>         QRoles;
typedef QHashIterator<int,QByteArray> QRoleItr;

using namespace std;
class submodel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged)
    Q_PROPERTY(QList<int> indexList READ indexList WRITE setIndexList NOTIFY indexListChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)


protected:
    QRoles roleNames() const {
        if(source == nullptr) {
            return QRoles();
        }
        return source->roleNames();
    }


public:
    submodel(QObject * parent = 0) : QAbstractListModel(parent) {
        source = NULL;
        nil = QJSValue::NullValue;
        clear() ;
     }

    //METHODS WE MUST PROVIDE!!
    QVariant data(const QModelIndex &index, int role) const {
        if(!index.isValid() || source == nullptr || index.row() < 0 || index.row() > indices.length())
            return nil.toVariant();


        int relativeIdx = indices[index.row()];
        if(relativeIdx < 0 || relativeIdx > source->rowCount())
            return nil.toVariant();

        //have to constract a QModelIndex like a boss from our QList
        return source->data(source->index(relativeIdx),role);
    }
    int rowCount(const QModelIndex &parent = QModelIndex()) const {
        return source == nullptr ? 0 : indices.length() ;
    }


    QAbstractListModel* sourceModel() { return source; }
    void setSourceModel(QObject *src){
        if(src != source) {
            disconnectSignals();

            source = reinterpret_cast<QAbstractListModel *>(src);
            if(source != nullptr) { //connect stuff
                connectSignals(source);
            }

            Q_EMIT sourceModelChanged();
        }
    }


    QList<int> indexList() {
        return indices;
    }
    void setIndexList(QList<int> intArr){
        safeList(intArr); //so everyuthing is kosher! i > 0  && i < rowCount of sourceModel

        //since we are going to overwrite this indexList, let's make sure we tell the view that we
        //don't need those delegated
        clear();

        indices = intArr;
        Q_EMIT indexListChanged();

        indexListSignals();
    }

    Q_INVOKABLE QStringList getRoleNames() {
        QStringList r;
        QRoleItr i(roleNames());
        while(i.hasNext()) {
            i.next();
            r.append(QString(i.value()));
        }
        return r;
    }
    Q_INVOKABLE QVariant get(int row){
        return (row < 0 || row > indices.length()) ? nil.toVariant() : sourceGet(indices[row]);
    }
    Q_INVOKABLE QVariant sourceGet(int row){
//        nanoTimer n;

        if(source == nullptr || row < 0 || row > source->rowCount())
            return nil.toVariant();

        QVariantMap res;
        QModelIndex idx = source->index(row, 0);

        QRoleItr i(roleNames());
        while(i.hasNext()) {
            i.next();
            QVariant data = idx.data(i.key());
            res[i.value()] = data;
        }


//        uint ns = n.stop();
//        qDebug() << "submodel::sourceGet(" << row << ").time\tns: " << ns << "\tms:" << ns / 1000000 ;

        return res;
    }
    Q_INVOKABLE void addToIndexList(int idx) {
        if(source != nullptr && !indices.contains(idx) && idx >= 0 && idx < source->rowCount()) {
            Q_EMIT beginInsertRows(QModelIndex(), indices.length(), indices.length());  //cause we will put it
            indices.append(idx);                                                         //at the end!
            Q_EMIT endInsertRows();
        }
    }
    Q_INVOKABLE void removeFromIndexList(int idx){
        int indexOf;
        if(-1 != (indexOf = indices.indexOf(idx))){
            Q_EMIT beginRemoveRows(QModelIndex(), indexOf, indexOf);
            indices.removeAt(indexOf);
            Q_EMIT endRemoveRows();
        }
    }
    Q_INVOKABLE void clear() {
        if(indices.length() > 0) {
            beginRemoveRows(QModelIndex(), 0, indices.length() - 1);
            endRemoveRows();
        }
        indices.clear();
        Q_EMIT countChanged(0);
        Q_EMIT indexListChanged();
    }


    Q_INVOKABLE void emitDataChanged(int start, int end, const QVector<int> &roles = QVector<int>()){
        emit dataChanged(index(start) ,index(end), roles);
    }




signals :
    void sourceModelChanged();
    void countChanged(int);
    void indexListChanged();

    void source_rowsInserted(uint start, uint end, uint count);
    void source_dataChanged(uint idx, uint refIdx, QVector<int> roles);
    void source_modelReset();



private:
    QAbstractListModel *source;     //the sourceModel
    QList<int> indices;             //indices that determine the subset of source
    QJSValue nil;                   //for ease of use mang!!


    //These are the connections (signals) we listen to from the source model!
    QMetaObject::Connection conn_rowsInserted;
    QMetaObject::Connection conn_rowsMoved;
    QMetaObject::Connection conn_rowsRemoved;
    QMetaObject::Connection conn_dataChanged;
    QMetaObject::Connection conn_modelReset;


    void connectSignals(QAbstractListModel *src) {
        conn_rowsInserted = connect(src, &QAbstractListModel::rowsInserted, this, &submodel::__rowsInserted);
        conn_rowsMoved    = connect(src, &QAbstractListModel::rowsMoved   , this, &submodel::__rowsMoved   );
        conn_rowsRemoved  = connect(src, &QAbstractListModel::rowsRemoved , this, &submodel::__rowsRemoved );
        conn_dataChanged  = connect(src, &QAbstractListModel::dataChanged , this, &submodel::__dataChanged );
        conn_modelReset   = connect(src, &QAbstractListModel::modelReset  , this, &submodel::__modelReset  );
    }

    void __rowsInserted(const QModelIndex &parent, int start, int end){
        //since we cant turn QVariant elems (from sourcemodel) into QJSValue here. We have to let JS handle this
        //and run its filter function.
        int count = end - start + 1;
        Q_EMIT source_rowsInserted(start,end,count);
    }

    void __rowsRemoved(const QModelIndex &parent , int start, int end) {
        int count = end - start + 1 ; //this is the amount of things that need it's indexes updated
        int r;
        for(int i = indices.length() -1; i >=0; --i){
            r = indices[i];
            if(r >= start && r <= end){
                Q_EMIT beginRemoveRows(QModelIndex(), i, i);
                indices.removeAt(i);
                Q_EMIT endRemoveRows();
            }
            else if(r > end){
                indices[i] -= count;
                //This has adjusted the indices to match? Shouldn't really have to trigger anything I think.
            }
        }
    }


    void __dataChanged(const QModelIndex &topLeft, const QModelIndex &bottomRight, const QVector<int> &roles = QVector<int>()) {
        //since we cant turn QVariant elems (from sourcemodel) into QJSValue here. We have to let JS handle this
        //and run its filter function.

//        qDebug() << topLeft.row() << "," << topLeft.column() << "::" << bottomRight.row() << "::" << bottomRight.column();
        int actualIdx = topLeft.row();
        int refIdx = -1;
        for(uint i = 0; i < indices.length(); ++i){
            if(indices[i] == actualIdx){
                refIdx = i;
                break;
            }
        }

        Q_EMIT source_dataChanged(actualIdx, refIdx, roles);
    }

//    void __dataChanged(const QModelIndex &topLeft, const QModelIndex &bottomRight, const QVector<int> &roles = QVector<int>()) {
//        //since we cant turn QVariant elems (from sourcemodel) into QJSValue here. We have to let JS handle this
//        //and run its filter function.

////        qDebug() << topLeft.row() << "," << topLeft.column() << "::" << bottomRight.row() << "::" << bottomRight.column();
//        QVector<int> refList;
//        for(uint j = topLeft.row(); j <= bottomRight.row(); ++j){

//            int refIdx = -1;
//            for(uint i = 0; i < indices.length(); ++i){
//                if(indices[i] == j){
//                    refIdx = i;
//                    break;
//                }
//            }
//            refList.push_back(refIdx);
//        }

//        //TODO let's make sure that the refIndice is in descending order so they can be sorted???
////        qDebug() << topLeft.row() << " " << bottomRight.row() << " " << refList.length();
//        Q_EMIT source_dataChanged(topLeft.row(), bottomRight.row(), refList, roles);
//    }

    void __modelReset() {
        Q_EMIT source_modelReset();
    }

    void __rowsMoved(const QModelIndex &parent, int fromStart, int fromEnd, const QModelIndex &destination, int row) {
        int count = fromEnd - fromStart +1;
        int toStart, toEnd;
        if(row < fromStart){
            toStart = row;
        }
        else if(row > fromEnd){
            toStart = row - count;
        }
        toEnd  = toStart + count - 1;

        int i, r, dist;
        if(fromStart > toStart){    //original elements moved up!
            dist = fromStart - toStart;
            for(i = 0; i < indices.length(); ++i){
                r   = indices[i];
                if(r >= toStart && r <= fromEnd){   //only these things will be affected!!
                    if(r >= fromStart && r <= fromEnd){ //if its the stuff moving up
                        indices[i] = r - dist;
                    }
                    else {  //its the stuff moving down
                        indices[i] = r + count;
                    }
                }
            }
            //EMIT stuff?
        }
        else if(fromStart < toStart) {  //original elements were moved down!
            dist              = toStart - fromStart;
            int elemsInMiddle = toStart - fromEnd - 1;
            for(i = 0; i < indices.length(); ++i){
                r   = indices[i];
                if(r >= fromStart && r <= toEnd){
                    if(r >= fromStart && r <= fromEnd){ //is in from
                        indices[i] = r + dist;
                    }
                    else if(r >= toStart && r <= toEnd){ //is in the to SEction
                        indices[i] = r - dist + elemsInMiddle;
                    }
                    else {  //is in the middle
                        indices[i] = r - count;
                    }
                }
            }
            //EMIT stuff?  probably no.
        }




    }




    void disconnectSignals() {
        disconnect(conn_rowsInserted);
        disconnect(conn_rowsMoved);
        disconnect(conn_rowsRemoved);
        disconnect(conn_dataChanged);
        disconnect(conn_modelReset);
    }
    void emitCountChanged(int count){
        if(rowCount() != count)
            emit countChanged(count);
    }
    void safeList(QList<int> &indices){
        if(source == nullptr){
            indices.clear();
        }

        for(int i = indices.length() - 1 ; i >= 0; --i) {
            int row = indices[i];
            if(row < 0 || row > source->rowCount())
                indices.removeAt(i);
        }
    }

    void indexListSignals(){
        if(source == nullptr)
            return;

        for(int i = 0; i < indices.length(); ++i) {
            int row = indices[i];
            if(row > -1 && row < source->rowCount()){
                beginInsertRows(QModelIndex(), i, i);
                endInsertRows();
            }
        }
        Q_EMIT countChanged(rowCount());
    }







};


#endif // SUBMODEL_H
