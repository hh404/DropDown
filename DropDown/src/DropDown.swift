//
//  DropDown.swift
//  DropDown
//
//  Created by Kevin Hirsch on 28/07/15.
//  Copyright (c) 2015 Kevin Hirsch. All rights reserved.
//

import UIKit

public typealias Index = Int
public typealias Closure = () -> Void
public typealias SelectionClosure = (Index, String) -> Void
public typealias ConfigurationClosure = (Index, String) -> String

/// A Material Design drop down in replacement for `UIPickerView`.
public final class DropDown: UIView {
	
	//TODO: handle iOS 7 landscape mode
	
	/// The dismiss mode for a drop down.
	public enum DismissMode {
		
		/// A tap outside the drop down is required to dismiss.
		case OnTap
		
		/// No tap is required to dismiss, it will dimiss when interacting with anything else.
		case Automatic
		
		/// Not dismissable by the user.
		case Manual
		
	}
	
	//MARK: - Properties
	
	/// The current visible drop down. There can be only one visible drop down at a time.
	public static weak var VisibleDropDown: DropDown?
	
	//MARK: UI
	private let dismissableView = UIView()
	private let tableViewContainer = UIView()
	private let tableView = UITableView()
	
	/// The view to which the drop down will displayed onto.
	public var anchorView: UIView! {
		didSet {
			setNeedsUpdateConstraints()
		}
	}
	
	/**
	The offset point relative to `anchorView`.
	
	By default, the drop down is showed onto the `anchorView` with the top
	left corner for its origin, so an offset equal to (0, 0).
	You can change here the default drop down origin.
	*/
	public var offset: CGPoint? {
		didSet {
			setNeedsUpdateConstraints()
		}
	}
	
	/**
	The width of the drop down.
	
	Defaults to `anchorView.bounds.width - offset.x`.
	*/
	public var width: CGFloat? {
		didSet {
			setNeedsUpdateConstraints()
		}
	}
	
	//MARK: Constraints
	private var heightConstraint: NSLayoutConstraint!
	private var widthConstraint: NSLayoutConstraint!
	private var xConstraint: NSLayoutConstraint!
	private var yConstraint: NSLayoutConstraint!
	
	//MARK: Appearance
	public override var backgroundColor: UIColor? {
		get {
			return tableView.backgroundColor
		}
		set {
			tableView.backgroundColor = newValue
		}
	}
	
	/**
	The background color of the selected cell in the drop down.
	
	Changing the background color automatically reloads the drop down.
	*/
	public dynamic var selectionBackgroundColor = UI.SelectionBackgroundColor {
		didSet {
			reloadAllComponents()
		}
	}
	
	/**
	The color of the text for each cells of the drop down.
	
	Changing the text color automatically reloads the drop down.
	*/
	public dynamic var textColor = UIColor.blackColor() {
		didSet {
			reloadAllComponents()
		}
	}
	
	/**
	The font of the text for each cells of the drop down.
	
	Changing the text font automatically reloads the drop down.
	*/
	public dynamic var textFont = UIFont.systemFontOfSize(15) {
		didSet {
			reloadAllComponents()
		}
	}
	
	//MARK: Content
	
	/**
	The data source for the drop down.
	
	Changing the data source automatically reloads the drop down.
	*/
	public var dataSource = [String]() {
		didSet {
			reloadAllComponents()
		}
	}
	
	private var selectedRowIndex: Index = -1
	
	/**
	The format for the cells' text.
	
	By default, the cell's text takes the plain `dataSource` value.
	Changing `cellConfiguration` automatically reloads the drop down.
	*/
	public var cellConfiguration: ConfigurationClosure? {
		didSet {
			reloadAllComponents()
		}
	}
	
	/// The action to execute when the user selects a cell.
	public var selectionAction: SelectionClosure!
	
	/// The action to execute when the user cancels/hides the drop down.
	public var cancelAction: Closure?
	
	/// The dismiss mode of the drop down. Default is `OnTap`.
	public var dismissMode = DismissMode.OnTap {
		willSet {
			if newValue == .OnTap {
				let gestureRecognizer = UITapGestureRecognizer(target: self, action: "dismissableViewTapped")
				dismissableView.addGestureRecognizer(gestureRecognizer)
			} else if let gestureRecognizer = dismissableView.gestureRecognizers?.first as? UIGestureRecognizer {
				dismissableView.removeGestureRecognizer(gestureRecognizer)
			}
		}
	}
	
	private var minHeight: CGFloat {
		return tableView.rowHeight
	}
	
	private var didSetupConstraints = false
	
	//MARK: - Init's
	
	deinit {
		stopListeningToNotifications()
	}
	
	/**
	Creates a new instance of a drop down.
	Don't forget to setup the `dataSource`, 
	the `anchorView` and the `selectionAction` 
	at least before calling `show()`.
	*/
	convenience init() {
		self.init(frame: CGRectZero)
	}
	
	/**
	Creates a new instance of a drop down.
	
	:param: dataSource        The data source for the drop down.
	:param: anchorView        The view to which the drop down will displayed onto.
	:param: offset            The offset point relative to `anchorView`.
	:param: cellConfiguration The format for the cells' text.
	:param: selectionAction   The action to execute when the user selects a cell.
	:param: cancelAction      The action to execute when the user cancels/hides the drop down.
	
	:returns: A new instance of a drop down customized with the above parameters.
	*/
	convenience init(dataSource: [String], anchorView: UIView? = nil, offset: CGPoint? = nil, cellConfiguration: ConfigurationClosure? = nil, selectionAction: SelectionClosure, cancelAction: Closure? = nil) {
		self.init()
		
		if let anchorView = anchorView {
			self.anchorView = anchorView
		}
		
		self.dataSource = dataSource
		self.offset = offset
		self.selectionAction = selectionAction
		self.cellConfiguration = cellConfiguration
		self.cancelAction = cancelAction
	}
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}
	
	required public init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}
	
}

//MARK: - Setup

private extension DropDown {
	
	func setup() {
		updateConstraintsIfNeeded()
		setupUI()
		
		dismissMode = .OnTap
		
		tableView.delegate = self
		tableView.dataSource = self
		
		tableView.registerNib(DropDownCell.Nib, forCellReuseIdentifier: ReusableIdentifier.DropDownCell)
		
		startListeningToKeyboard()
	}
	
	func setupUI() {
		super.backgroundColor = UIColor.clearColor()
		
		tableViewContainer.layer.masksToBounds = false
		tableViewContainer.layer.cornerRadius = UI.CornerRadius
		tableViewContainer.layer.shadowColor = UI.Shadow.Color
		tableViewContainer.layer.shadowOffset = UI.Shadow.Offset
		tableViewContainer.layer.shadowOpacity = UI.Shadow.Opacity
		tableViewContainer.layer.shadowRadius = UI.Shadow.Radius
		
		backgroundColor = UI.BackgroundColor
		tableView.rowHeight = UI.RowHeight
		tableView.separatorColor = UI.SeparatorColor
		tableView.layer.cornerRadius = UI.CornerRadius
		tableView.layer.masksToBounds = true
		
		setHiddentState()
		hidden = true
	}
	
}

//MARK: - UI

extension DropDown {
	
	public override func updateConstraints() {
		if !didSetupConstraints {
			setupConstraints()
		}
		
		didSetupConstraints = true
		
		xConstraint.constant = (anchorView?.windowFrame?.minX ?? 0) + (offset?.x ?? 0)
		yConstraint.constant = (anchorView?.windowFrame?.minY ?? 0) + (offset?.y ?? 0)
		widthConstraint.constant = width ?? (anchorView?.bounds.width ?? 0) - (offset?.x ?? 0)
		
		let (visibleHeight, offScreenHeight, canBeDisplayed) = computeHeightForDisplay()
		
		if !canBeDisplayed {
			super.updateConstraints()
			hide()
			
			return
		}
		
		heightConstraint.constant = visibleHeight
		tableView.scrollEnabled = offScreenHeight > 0
		
		dispatch_async(dispatch_get_main_queue()) { [unowned self] in
			self.tableView.flashScrollIndicators()
		}
		
		super.updateConstraints()
	}
	
	private func setupConstraints() {
		setTranslatesAutoresizingMaskIntoConstraints(false)
		
		// Dismissable view
		addSubview(dismissableView)
		dismissableView.setTranslatesAutoresizingMaskIntoConstraints(false)
		
		addUniversalConstraints(format: "|[dismissableView]|", views: ["dismissableView": dismissableView])
		
		
		// Table view container
		addSubview(tableViewContainer)
		tableViewContainer.setTranslatesAutoresizingMaskIntoConstraints(false)
		
		xConstraint = NSLayoutConstraint(
			item: tableViewContainer,
			attribute: .Leading,
			relatedBy: .Equal,
			toItem: self,
			attribute: .Leading,
			multiplier: 1,
			constant: 0)
		addConstraint(xConstraint)
		
		yConstraint = NSLayoutConstraint(
			item: tableViewContainer,
			attribute: .Top,
			relatedBy: .Equal,
			toItem: self,
			attribute: .Top,
			multiplier: 1,
			constant: 0)
		addConstraint(yConstraint)
		
		widthConstraint = NSLayoutConstraint(
			item: tableViewContainer,
			attribute: .Width,
			relatedBy: .Equal,
			toItem: nil,
			attribute: .NotAnAttribute,
			multiplier: 1,
			constant: 0)
		tableViewContainer.addConstraint(widthConstraint)
		
		heightConstraint = NSLayoutConstraint(
			item: tableViewContainer,
			attribute: .Height,
			relatedBy: .Equal,
			toItem: nil,
			attribute: .NotAnAttribute,
			multiplier: 1,
			constant: 0)
		tableViewContainer.addConstraint(heightConstraint)
		
		// Table view
		tableViewContainer.addSubview(tableView)
		tableView.setTranslatesAutoresizingMaskIntoConstraints(false)
		
		tableViewContainer.addUniversalConstraints(format: "|[tableView]|", views: ["tableView": tableView])
	}
	
	public override func layoutSubviews() {
		super.layoutSubviews()
		
		// When orientation changes, layoutSubviews is called
		// We update the constraint to update the position
		setNeedsUpdateConstraints()
		
		let shadowPath = UIBezierPath(rect: tableViewContainer.bounds)
		tableViewContainer.layer.shadowPath = shadowPath.CGPath
	}
	
	private func computeHeightForDisplay() -> (visibleHeight: CGFloat, offScreenHeight: CGFloat?, canBeDisplayed: Bool) {
		var offscreenHeight: CGFloat = 0
		
		if let window = UIWindow.visibleWindow() {
			let maxY = tableHeight + yConstraint.constant
			let windowMaxY = window.bounds.maxY - UI.HeightPadding
			let keyboardListener = KeyboardListener.sharedInstance
			let keyboardMinY = keyboardListener.keyboardFrame.minY - UI.HeightPadding
			
			if keyboardListener.isVisible && maxY > keyboardMinY {
				offscreenHeight = abs(maxY - keyboardMinY)
			} else if maxY > windowMaxY {
				offscreenHeight = abs(maxY - windowMaxY)
			}
		}
		
		let visibleHeight = tableHeight - offscreenHeight
		let canBeDisplayed = visibleHeight >= minHeight
		let optionalOffscreenHeight: CGFloat? = offscreenHeight == 0 ? nil : offscreenHeight
		
		return (visibleHeight, optionalOffscreenHeight, canBeDisplayed)
	}
	
}

//MARK: - Actions

extension DropDown {
	
	/**
	Shows the drop down if enough height.
	
	:returns: Wether it succeed and how much height is needed to display all cells at once.
	*/
	public func show() -> (canBeDisplayed: Bool, offscreenHeight: CGFloat?) {
		if let visibleDropDown = DropDown.VisibleDropDown {
			visibleDropDown.cancel()
		}
		
		DropDown.VisibleDropDown = self
		
		setNeedsUpdateConstraints()
		
		let visibleWindow = UIWindow.visibleWindow()
		visibleWindow?.addSubview(self)
		visibleWindow?.bringSubviewToFront(self)
		
		self.setTranslatesAutoresizingMaskIntoConstraints(false)
		visibleWindow?.addUniversalConstraints(format: "|[dropDown]|", views: ["dropDown": self])
		
		let (_, offScreenHeight, canBeDisplayed) = computeHeightForDisplay()
		
		if !canBeDisplayed {
			hide()
			return (canBeDisplayed, offScreenHeight)
		}
		
		hidden = false
		tableViewContainer.transform = Animation.DownScaleTransform
		
		UIView.animateWithDuration(
			Animation.Duration,
			delay: 0,
			options: Animation.EntranceOptions,
			animations: { [unowned self] in
				self.setShowedState()
			},
			completion: nil)
		
		selectRowAtIndex(selectedRowIndex)
		
		return (canBeDisplayed, offScreenHeight)
	}
	
	/// Hides the drop down.
	public func hide() {
		DropDown.VisibleDropDown = nil
		
		UIView.animateWithDuration(
			Animation.Duration,
			delay: 0,
			options: Animation.ExitOptions,
			animations: { [unowned self] in
				self.setHiddentState()
			},
			completion: { [unowned self] finished in
				self.hidden = true
				self.removeFromSuperview()
			})
	}
	
	private func cancel() {
		hide()
		cancelAction?()
	}
	
	private func setHiddentState() {
		alpha = 0
	}
	
	private func setShowedState() {
		alpha = 1
		tableViewContainer.transform = CGAffineTransformIdentity
	}
	
}

//MARK: - UITableView

extension DropDown {
	
	/**
	Reloads all the cells.
	
	It should not be necessary in most cases because each change to
	`dataSource`, `textColor`, `textFont`, `selectionBackgroundColor`
	and `cellConfiguration` implicitly calls `reloadAllComponents()`.
	*/
	public func reloadAllComponents() {
		tableView.reloadData()
		setNeedsUpdateConstraints()
	}
	
	/// (Pre)selects a row at a certain index.
	public func selectRowAtIndex(index: Index) {
		selectedRowIndex = index
		
		tableView.selectRowAtIndexPath(
			NSIndexPath(forRow: index, inSection: 0),
			animated: false,
			scrollPosition: .Middle)
	}
	
	/// Returns the index of the selected row.
	public func indexForSelectedRow() -> Index? {
		return tableView.indexPathForSelectedRow()?.row
	}
	
	/// Returns the selected item.
	public func selectedItem() -> String? {
		if let row = tableView.indexPathForSelectedRow()?.row {
			return dataSource[row]
		} else {
			return nil
		}
	}
	
	/// Returns the height needed to display all cells.
	private var tableHeight: CGFloat {
		return tableView.rowHeight * CGFloat(dataSource.count)
	}
	
}

//MARK: - UITableViewDataSource - UITableViewDelegate

extension DropDown: UITableViewDataSource, UITableViewDelegate {
	
	public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}
	
	public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier(ReusableIdentifier.DropDownCell, forIndexPath: indexPath) as! DropDownCell
		
		cell.optionLabel.textColor = textColor
		cell.optionLabel.font = textFont
		cell.selectedBackgroundColor = selectionBackgroundColor
		
		if let cellConfiguration = cellConfiguration {
			let index = indexPath.row
			cell.optionLabel.text = cellConfiguration(index, dataSource[index])
		} else {
			cell.optionLabel.text = dataSource[indexPath.row]
		}
		
		return cell
	}
	
	public func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
		cell.selected = indexPath.row == selectedRowIndex
	}
	
	public func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		selectedRowIndex = indexPath.row
		selectionAction(selectedRowIndex, dataSource[selectedRowIndex])
		hide()
	}
	
}

//MARK: - Auto dismiss

extension DropDown {
	
	public override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
		let view = super.hitTest(point, withEvent: event)
		
		if dismissMode == .Automatic && view === dismissableView {
			cancel()
			return nil
		} else {
			return view
		}
	}
	
	@objc
	private func dismissableViewTapped() {
		cancel()
	}
	
}

//MARK: - Keyboard events

extension DropDown {
	
	/**
	Starts listening to keyboard events.
	Allows the drop down to display correctly when keyboard is showed.
	*/
	public static func startListeningToKeyboard() {
		KeyboardListener.sharedInstance.startListeningToKeyboard()
	}
	
	private func startListeningToKeyboard() {
		KeyboardListener.sharedInstance.startListeningToKeyboard()
		
		NSNotificationCenter.defaultCenter().addObserver(
			self,
			selector: "keyboardUpdate",
			name: UIKeyboardDidShowNotification,
			object: nil)
		NSNotificationCenter.defaultCenter().addObserver(
			self,
			selector: "keyboardUpdate",
			name: UIKeyboardDidHideNotification,
			object: nil)
	}
	
	private func stopListeningToNotifications() {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	@objc
	private func keyboardUpdate() {
		self.setNeedsUpdateConstraints()
	}
	
}