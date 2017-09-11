//
//  DragDropCollectionView.swift
//  DragDrop
//
//  Created by Cyning on 2017/9/11.
//  Copyright (c) 2017 Cyning. All rights reserved.
// 3rd test for git submodule
//Just testing git subtree for the second time
import UIKit

@objc
public protocol DrapDropCollectionViewDelegate {
    @objc(dragDropCollectionViewDidMoveCellFromInitialIndexPath:toNewIndexPath:)
    func dragDropCollectionViewDidMoveCellFromInitialIndexPath(_ initialIndexPath: IndexPath, toNewIndexPath newIndexPath: IndexPath)
    
    @objc(dragDropCollectionViewDidOperate)
    optional func dragDropCollectionViewDidOperate();
    
    @objc(dragDropCollectionViewDraggingDidBeginWithCellAtIndexPath:)
    optional func dragDropCollectionViewDraggingDidBeginWithCellAtIndexPath(_ indexPath: IndexPath)
    
    @objc(dragDropCollectionViewDraggingDidEndForCellAtIndexPath:)
    optional func dragDropCollectionViewDraggingDidEndForCellAtIndexPath(_ indexPath: IndexPath)
}

@objc
open class DragDropCollectionView: UICollectionView, UIGestureRecognizerDelegate {
    open weak var draggingDelegate: DrapDropCollectionViewDelegate?
    
    var longPressRecognizer: UILongPressGestureRecognizer = {
        let longPressRecognizer = UILongPressGestureRecognizer()
        longPressRecognizer.delaysTouchesBegan = false
        longPressRecognizer.cancelsTouchesInView = false
        longPressRecognizer.numberOfTouchesRequired = 1
        longPressRecognizer.minimumPressDuration = 0.8
        longPressRecognizer.allowableMovement = 10.0
        return longPressRecognizer
    }()
    
    var commonGestureRecognizer: UIPanGestureRecognizer = {
        let gestureRecognizer = UIPanGestureRecognizer()
        return gestureRecognizer
    }()
    
    fileprivate var draggedCellIndexPath: IndexPath?
    var draggingView: UIView?
    fileprivate var touchOffsetFromCenterOfCell: CGPoint?
    var isWiggling = false
    fileprivate let pingInterval = 0.3
    var isAutoScrolling = false
    
    open override var intrinsicContentSize: CGSize {
        self.layoutIfNeeded()
        return CGSize(width: UIViewNoIntrinsicMetric, height: self.contentSize.height)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        commonInit()
    }
    
    fileprivate func commonInit() {
        longPressRecognizer.addTarget(self, action: #selector(DragDropCollectionView.handleLongPress(_:)))
        longPressRecognizer.isEnabled = true
        
        commonGestureRecognizer.addTarget(self, action: #selector(DragDropCollectionView.handleDragRecognizer(_:)))
        commonGestureRecognizer.isEnabled = false
        
        self.addGestureRecognizer(longPressRecognizer)
        self.addGestureRecognizer(commonGestureRecognizer)
        
    }
    
    open override func reloadData() {
        super.reloadData()
        self.invalidateIntrinsicContentSize()
    }
    
    @objc(stopDragging)
    open func stopDragging(){
        stopWiggle()
        commonGestureRecognizer.isEnabled = false
        longPressRecognizer.isEnabled = true
    }
    
    func handleDragRecognizer(_ gestureRecognizer: UIPanGestureRecognizer){
        let touchLocation = gestureRecognizer.location(in: self)
        
        switch (gestureRecognizer.state) {
        case UIGestureRecognizerState.began:
            draggedCellIndexPath = self.indexPathForItem(at: touchLocation)
            if (draggedCellIndexPath != nil) {
                draggingDelegate?.dragDropCollectionViewDraggingDidBeginWithCellAtIndexPath?(draggedCellIndexPath!)
                let draggedCell = self.cellForItem(at: draggedCellIndexPath! as IndexPath) as UICollectionViewCell!
                draggingView = UIImageView(image: getRasterizedImageCopyOfCell(draggedCell!))
                draggingView!.center = (draggedCell!.center)
                self.addSubview(draggingView!)
                draggedCell!.alpha = 0.0
                touchOffsetFromCenterOfCell = CGPoint(x: draggedCell!.center.x - touchLocation.x, y: draggedCell!.center.y - touchLocation.y)
                UIView.animate(withDuration: 0.4, animations: { () -> Void in
                    self.draggingView!.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                    self.draggingView!.alpha = 0.8
                })
            }
            
        case UIGestureRecognizerState.changed:
            if draggedCellIndexPath != nil {
                draggingView!.center = CGPoint(x: touchLocation.x + touchOffsetFromCenterOfCell!.x, y: touchLocation.y + touchOffsetFromCenterOfCell!.y)
                
                if !isAutoScrolling {
                    
                    dispatchOnMainQueueAfter(pingInterval, closure: { () -> () in
                        let scroller = self.shouldAutoScroll(touchLocation)
                        if  (scroller.shouldScroll) {
                            self.autoScroll(scroller.direction)
                            self.isAutoScrolling = true
                        }
                    })
                }
                
                dispatchOnMainQueueAfter(pingInterval, closure: { () -> () in
                    let shouldSwapCellsTuple = self.shouldSwapCells(touchLocation)
                    if shouldSwapCellsTuple.shouldSwap {
                        self.swapDraggedCellWithCellAtIndexPath(shouldSwapCellsTuple.newIndexPath!)
                    }
                })
            }
        case UIGestureRecognizerState.ended:
            if draggedCellIndexPath != nil {
                draggingDelegate?.dragDropCollectionViewDraggingDidEndForCellAtIndexPath?(draggedCellIndexPath!)
                let draggedCell = self.cellForItem(at: draggedCellIndexPath! as IndexPath)
                UIView.animate(withDuration: 0.4, animations: { () -> Void in
                    self.draggingView!.transform = CGAffineTransform.identity
                    self.draggingView!.alpha = 1.0
                    if (draggedCell != nil) {
                        self.draggingView!.center = draggedCell!.center
                    }
                }, completion: { (finished) -> Void in
                    self.draggingView!.removeFromSuperview()
                    self.draggingView = nil
                    draggedCell?.alpha = 1.0
                    self.draggedCellIndexPath = nil
                })
            }
        default: ()
        }
    }
    
    func handleLongPress(_ longPressRecognizer: UILongPressGestureRecognizer) {
        
        let touchLocation = longPressRecognizer.location(in: self)
        switch (longPressRecognizer.state) {
        case UIGestureRecognizerState.began:
            let indexPath = self.indexPathForItem(at: touchLocation)
            if (indexPath != nil) {
                draggingDelegate?.dragDropCollectionViewDidOperate?()
                
                startWiggle()
                longPressRecognizer.isEnabled = false;
                commonGestureRecognizer.isEnabled = true;
            }
        default: ()
        }
    }
    
    
    
    fileprivate func shouldSwapCells(_ previousTouchLocation: CGPoint) -> (shouldSwap: Bool, newIndexPath: IndexPath?) {
        var shouldSwap = false
        var newIndexPath: IndexPath?
        let currentTouchLocation = self.commonGestureRecognizer.location(in: self)
        if !Double(currentTouchLocation.x).isNaN && !Double(currentTouchLocation.y).isNaN {
            if distanceBetweenPoints(previousTouchLocation, secondPoint: currentTouchLocation) < CGFloat(20.0) {
                if let newIndexPathForCell = self.indexPathForItem(at: currentTouchLocation) {
                    if newIndexPathForCell != self.draggedCellIndexPath! as IndexPath {
                        shouldSwap = true
                        newIndexPath = newIndexPathForCell
                    }
                }
            }
        }
        return (shouldSwap, newIndexPath)
    }
    
    fileprivate func swapDraggedCellWithCellAtIndexPath(_ newIndexPath: IndexPath) {
        self.moveItem(at: self.draggedCellIndexPath! as IndexPath, to: newIndexPath as IndexPath)
        let draggedCell = self.cellForItem(at: newIndexPath as IndexPath)!
        draggedCell.alpha = 0
        self.draggingDelegate?.dragDropCollectionViewDidMoveCellFromInitialIndexPath(self.draggedCellIndexPath!, toNewIndexPath: newIndexPath)
        self.draggedCellIndexPath = newIndexPath
    }
    
    
}

//AutoScroll
extension DragDropCollectionView {
    enum AutoScrollDirection: Int {
        case invalid = 0
        case towardsOrigin = 1
        case awayFromOrigin = 2
    }
    
    func autoScroll(_ direction: AutoScrollDirection) {
        let currentLongPressTouchLocation = self.commonGestureRecognizer.location(in: self)
        var increment: CGFloat
        var newContentOffset: CGPoint
        if (direction == AutoScrollDirection.towardsOrigin) {
            increment = -50.0
        } else {
            increment = 50.0
        }
        newContentOffset = CGPoint(x: self.contentOffset.x, y: self.contentOffset.y + increment)
        let flowLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        if flowLayout.scrollDirection == UICollectionViewScrollDirection.horizontal{
            newContentOffset = CGPoint(x: self.contentOffset.x + increment, y: self.contentOffset.y)
        }
        if ((direction == AutoScrollDirection.towardsOrigin && newContentOffset.y < 0) || (direction == AutoScrollDirection.awayFromOrigin && newContentOffset.y > self.contentSize.height - self.frame.height)) {
            dispatchOnMainQueueAfter(0.3, closure: { () -> () in
                self.isAutoScrolling = false
            })
        } else {
            UIView.animate(withDuration: 0.3
                , delay: 0.0
                , options: UIViewAnimationOptions.curveLinear
                , animations: { () -> Void in
                    self.setContentOffset(newContentOffset, animated: false)
                    if (self.draggingView != nil) {
                        if flowLayout.scrollDirection == UICollectionViewScrollDirection.vertical{
                            var draggingFrame = self.draggingView!.frame
                            draggingFrame.origin.y += increment
                            self.draggingView!.frame = draggingFrame
                        }else{
                            var draggingFrame = self.draggingView!.frame
                            draggingFrame.origin.x += increment
                            self.draggingView!.frame = draggingFrame
                        }
                    }
            }) { (finished) -> Void in
                dispatchOnMainQueueAfter(0.0, closure: { () -> () in
                    var updatedTouchLocationWithNewOffset = CGPoint(x: currentLongPressTouchLocation.x, y: currentLongPressTouchLocation.y + increment)
                    if flowLayout.scrollDirection == UICollectionViewScrollDirection.horizontal{
                        updatedTouchLocationWithNewOffset = CGPoint(x: currentLongPressTouchLocation.x + increment, y: currentLongPressTouchLocation.y)
                    }
                    let scroller = self.shouldAutoScroll(updatedTouchLocationWithNewOffset)
                    if scroller.shouldScroll {
                        self.autoScroll(scroller.direction)
                    } else {
                        self.isAutoScrolling = false
                    }
                })
            }
        }
    }
    
    func shouldAutoScroll(_ previousTouchLocation: CGPoint) -> (shouldScroll: Bool, direction: AutoScrollDirection) {
        let previousTouchLocation = self.convert(previousTouchLocation, to: self.superview)
        let currentTouchLocation = self.commonGestureRecognizer.location(in: self.superview)
        
        if let flowLayout = self.collectionViewLayout as? UICollectionViewFlowLayout {
            if !Double(currentTouchLocation.x).isNaN && !Double(currentTouchLocation.y).isNaN {
                if distanceBetweenPoints(previousTouchLocation, secondPoint: currentTouchLocation) < CGFloat(20.0) {
                    let scrollDirection = flowLayout.scrollDirection
                    var scrollBoundsSize: CGSize
                    let scrollBoundsLength: CGFloat = 50.0
                    var scrollRectAtEnd: CGRect
                    switch scrollDirection {
                    case UICollectionViewScrollDirection.horizontal:
                        scrollBoundsSize = CGSize(width: scrollBoundsLength, height: self.frame.height)
                        scrollRectAtEnd = CGRect(x: self.frame.origin.x + self.frame.width - scrollBoundsSize.width , y: self.frame.origin.y, width: scrollBoundsSize.width, height: self.frame.height)
                    case UICollectionViewScrollDirection.vertical:
                        scrollBoundsSize = CGSize(width: self.frame.width, height: scrollBoundsLength)
                        scrollRectAtEnd = CGRect(x: self.frame.origin.x, y: self.frame.origin.y + self.frame.height - scrollBoundsSize.height, width: self.frame.width, height: scrollBoundsSize.height)
                    }
                    let scrollRectAtOrigin = CGRect(origin: self.frame.origin, size: scrollBoundsSize)
                    if scrollRectAtOrigin.contains(currentTouchLocation) {
                        return (true, AutoScrollDirection.towardsOrigin)
                    } else if scrollRectAtEnd.contains(currentTouchLocation) {
                        return (true, AutoScrollDirection.awayFromOrigin)
                    }
                }
            }
        }
        return (false, AutoScrollDirection.invalid)
    }
}

//Wiggle Animation
extension DragDropCollectionView {
    @objc(startWiggle)
    open func startWiggle() {
        for cell in visibleCells {
            addWiggleAnimationTo(cell )
        }
        isWiggling = true
    }
    
    @objc(stopWiggle)
    open func stopWiggle() {
        for cell in visibleCells {
            cell.layer.removeAllAnimations()
        }
        isWiggling = false
    }
    
    override open func dequeueReusableCell(withReuseIdentifier identifier: String, for indexPath: IndexPath) -> UICollectionViewCell {
        let cell: AnyObject = super.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath as IndexPath)
        if isWiggling {
            addWiggleAnimationTo(cell as! UICollectionViewCell)
        } else {
            cell.layer.removeAllAnimations()
        }
        return cell as! UICollectionViewCell
    }
    
    @objc(addWiggleAnimationTo:)
    open func addWiggleAnimationTo(_ cell: UICollectionViewCell) {
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        cell.layer.add(rotationAnimation(), forKey: "rotation")
        cell.layer.add(bounceAnimation(), forKey: "bounce")
        CATransaction.commit()
    }
    
    fileprivate func rotationAnimation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let angle = CGFloat(0.04)
        let duration = TimeInterval(0.1)
        let variance = Double(0.025)
        animation.values = [angle, -angle]
        animation.autoreverses = true
        animation.duration = self.randomize(duration, withVariance: variance)
        animation.repeatCount = Float.infinity
        return animation
    }
    
    fileprivate func bounceAnimation() -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        let bounce = CGFloat(3.0)
        let duration = TimeInterval(0.12)
        let variance = Double(0.025)
        animation.values = [bounce, -bounce]
        animation.autoreverses = true
        animation.duration = self.randomize(duration, withVariance: variance)
        animation.repeatCount = Float.infinity
        return animation
    }
    
    fileprivate func randomize(_ interval: TimeInterval, withVariance variance:Double) -> TimeInterval {
        let random = (Double(arc4random_uniform(1000)) - 500.0) / 500.0
        return interval + variance * random;
    }
}

//Assisting Functions
extension DragDropCollectionView {
    func getRasterizedImageCopyOfCell(_ cell: UICollectionViewCell) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(cell.bounds.size, false, 0.0)
        cell.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}

public func dispatchOnMainQueueAfter(_ delay:Double, closure:@escaping ()->Void) {
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+delay, qos: DispatchQoS.userInteractive, flags: DispatchWorkItemFlags.enforceQoS, execute: closure)
}

public func distanceBetweenPoints(_ firstPoint: CGPoint, secondPoint: CGPoint) -> CGFloat {
    let xDistance = firstPoint.x - secondPoint.x
    let yDistance = firstPoint.y - secondPoint.y
    return sqrt(xDistance * xDistance + yDistance * yDistance)
}
