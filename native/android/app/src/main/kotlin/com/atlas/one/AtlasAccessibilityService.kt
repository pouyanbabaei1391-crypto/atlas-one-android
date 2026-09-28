package com.atlas.one

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class AtlasAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var instance: AtlasAccessibilityService? = null
    }
    override fun onServiceConnected() { super.onServiceConnected(); instance = this }
    override fun onDestroy() { if (instance === this) instance = null; super.onDestroy() }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    fun observe(): String {
        val root = rootInActiveWindow ?: return ""
        val out = ArrayList<String>()
        fun walk(n: AccessibilityNodeInfo?, depth: Int) {
            if (n == null || out.size >= 160 || depth > 18) return
            val text = (n.text ?: n.contentDescription)?.toString()?.trim().orEmpty()
            if (text.isNotEmpty()) out.add(text.take(160))
            for (i in 0 until n.childCount) walk(n.getChild(i), depth + 1)
        }
        walk(root, 0)
        return out.distinct().joinToString("\n").take(12000)
    }

    fun clickText(target: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByText(target)
        for (node in nodes) {
            var cur: AccessibilityNodeInfo? = node
            repeat(5) {
                if (cur?.isClickable == true && cur?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true) return true
                cur = cur?.parent
            }
        }
        return false
    }

    fun setFocusedText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: findEditable(root)
            ?: return false
        val args = Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text) }
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    private fun findEditable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isEditable) return node
        for (i in 0 until node.childCount) findEditable(node.getChild(i))?.let { return it }
        return null
    }

    fun scroll(direction: Int): Boolean {
        val root = rootInActiveWindow ?: return false
        fun walk(n: AccessibilityNodeInfo?): Boolean {
            if (n == null) return false
            if (n.isScrollable) {
                val action = if (direction < 0) AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD else AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                if (n.performAction(action)) return true
            }
            for (i in 0 until n.childCount) if (walk(n.getChild(i))) return true
            return false
        }
        return walk(root)
    }

    fun pressEnter(): Boolean {
        val root = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        val args = Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, (focused.text?.toString() ?: "") + "\n") }
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun pressTab(): Boolean {
        val root = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        val next = focused.focusSearch(android.view.View.FOCUS_FORWARD) ?: return false
        return next.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
    }

}
