package com.atlas.one

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

class AtlasAccessibilityService : AccessibilityService() {
    companion object { @Volatile var instance: AtlasAccessibilityService? = null }
    override fun onServiceConnected() { super.onServiceConnected(); instance = this }
    override fun onDestroy() { if (instance === this) instance = null; super.onDestroy() }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    fun observe(): String {
        val root = rootInActiveWindow ?: return ""
        val out = ArrayList<String>()
        walk(root, 0) { n, _ ->
            val text = (n.text ?: n.contentDescription)?.toString()?.trim().orEmpty()
            if (text.isNotEmpty() && out.size < 220) out.add(text.take(220))
        }
        return out.distinct().joinToString("\n").take(16000)
    }

    fun observeStructured(): String {
        val root = rootInActiveWindow ?: return JSONObject().put("nodes", JSONArray()).toString()
        val result = JSONObject()
        result.put("package", root.packageName?.toString() ?: "")
        result.put("windowClass", root.className?.toString() ?: "")
        val nodes = JSONArray()
        var index = 0
        walk(root, 0) { n, depth ->
            if (index >= 280) return@walk
            val r = android.graphics.Rect(); n.getBoundsInScreen(r)
            val o = JSONObject()
            o.put("i", index++)
            o.put("depth", depth)
            o.put("text", n.text?.toString()?.take(300) ?: "")
            o.put("desc", n.contentDescription?.toString()?.take(300) ?: "")
            o.put("viewId", n.viewIdResourceName ?: "")
            o.put("class", n.className?.toString() ?: "")
            o.put("clickable", n.isClickable)
            o.put("editable", n.isEditable)
            o.put("scrollable", n.isScrollable)
            o.put("enabled", n.isEnabled)
            o.put("focused", n.isFocused)
            o.put("bounds", "${r.left},${r.top},${r.right},${r.bottom}")
            nodes.put(o)
        }
        result.put("nodes", nodes)
        return result.toString().take(64000)
    }

    private fun walk(root: AccessibilityNodeInfo?, depth: Int, fn: (AccessibilityNodeInfo, Int) -> Unit) {
        if (root == null || depth > 24) return
        fn(root, depth)
        for (i in 0 until root.childCount) walk(root.getChild(i), depth + 1, fn)
    }

    private fun clickableParent(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        var cur = node
        repeat(7) { if (cur?.isClickable == true) return cur; cur = cur?.parent }
        return null
    }

    fun clickText(target: String): Boolean {
        if (target.isBlank()) return false
        val root = rootInActiveWindow ?: return false
        val exact = ArrayList<AccessibilityNodeInfo>()
        walk(root, 0) { n, _ ->
            val t=n.text?.toString()?.trim(); val d=n.contentDescription?.toString()?.trim()
            if (t.equals(target,true) || d.equals(target,true)) exact.add(n)
        }
        val candidates = if (exact.isNotEmpty()) exact else root.findAccessibilityNodeInfosByText(target)
        for (n in candidates) {
            val c=clickableParent(n) ?: n
            if (c.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true
        }
        return false
    }

    fun clickViewId(viewId: String): Boolean {
        val root=rootInActiveWindow ?: return false
        if (viewId.isBlank()) return false
        val nodes=try { root.findAccessibilityNodeInfosByViewId(viewId) } catch (_:Throwable) { emptyList() }
        for(n in nodes) { val c=clickableParent(n) ?: n; if(c.performAction(AccessibilityNodeInfo.ACTION_CLICK)) return true }
        return false
    }

    fun focusText(target: String): Boolean {
        val root=rootInActiveWindow ?: return false
        val nodes=root.findAccessibilityNodeInfosByText(target)
        for(n in nodes) if(n.performAction(AccessibilityNodeInfo.ACTION_FOCUS)) return true
        return false
    }

    fun setFocusedText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: findEditable(root) ?: return false
        val args = Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text) }
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun setTextInFirstEditable(text: String): Boolean {
        val root=rootInActiveWindow ?: return false
        val target=findEditable(root) ?: return false
        target.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val args=Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,text) }
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT,args)
    }

    private fun findEditable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isEditable && node.isEnabled) return node
        for (i in 0 until node.childCount) findEditable(node.getChild(i))?.let { return it }
        return null
    }



    fun longClickFirstImage(): Boolean {
        val root = rootInActiveWindow ?: return false
        var chosen: AccessibilityNodeInfo? = null
        walk(root, 0) { n, _ ->
            if (chosen != null || !n.isEnabled) return@walk
            val klass = n.className?.toString()?.lowercase().orEmpty()
            val desc = n.contentDescription?.toString()?.lowercase().orEmpty()
            val text = n.text?.toString()?.lowercase().orEmpty()
            val r = android.graphics.Rect(); n.getBoundsInScreen(r)
            val label = "$desc $text"
            val rejected = label.contains("google") || label.contains("logo") || label.contains("profile") || label.contains("avatar") || label.contains("icon")
            val looksImage = klass.contains("image") || desc.contains("image") || desc.contains("photo") || text.contains("image")
            val largeEnough = r.width() >= 90 && r.height() >= 70 && r.top >= 120
            if (!rejected && looksImage && largeEnough && (n.actionList.any { it.id == AccessibilityNodeInfo.ACTION_LONG_CLICK } || n.isClickable)) {
                chosen = n
            }
        }
        val node = chosen ?: return false
        if (node.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK)) return true
        val parent = clickableParent(node)
        if (parent?.performAction(AccessibilityNodeInfo.ACTION_LONG_CLICK) == true) return true
        val r = android.graphics.Rect(); node.getBoundsInScreen(r)
        if (r.width() <= 4 || r.height() <= 4) return false
        val path = Path().apply { moveTo(r.exactCenterX(), r.exactCenterY()) }
        val stroke = GestureDescription.StrokeDescription(path, 0, 850)
        return dispatchGesture(GestureDescription.Builder().addStroke(stroke).build(), null, null)
    }

    fun clickFirstMeaningfulLink(): Boolean {
        val root = rootInActiveWindow ?: return false
        val rejected = listOf(
            "search", "google", "images", "videos", "maps", "news", "shopping", "sign in", "menu",
            "جستجو", "تصاویر", "ویدیو", "اخبار", "نقشه", "ورود"
        )
        var candidate: AccessibilityNodeInfo? = null
        walk(root, 0) { n, depth ->
            if (candidate != null || depth < 2 || !n.isEnabled || n.isEditable) return@walk
            val label = ((n.text ?: n.contentDescription)?.toString() ?: "").trim()
            if (label.length < 12) return@walk
            val lower = label.lowercase()
            if (rejected.any { lower == it || lower.startsWith("$it ") }) return@walk
            val clickable = clickableParent(n)
            if (clickable != null && clickable.isEnabled) candidate = clickable
        }
        return candidate?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
    }

    fun clickFirstFileCandidate(): Boolean {
        val root = rootInActiveWindow ?: return false
        val extensions = listOf(".jpg", ".jpeg", ".png", ".webp", ".gif", ".pdf", ".txt", ".doc", ".docx")
        var candidate: AccessibilityNodeInfo? = null
        walk(root, 0) { n, _ ->
            if (candidate != null || !n.isEnabled) return@walk
            val label = ((n.text ?: n.contentDescription)?.toString() ?: "").trim()
            if (label.isEmpty()) return@walk
            val lower = label.lowercase()
            if (!extensions.any { lower.contains(it) }) return@walk
            candidate = clickableParent(n) ?: if (n.isClickable) n else null
        }
        return candidate?.performAction(AccessibilityNodeInfo.ACTION_CLICK) ?: false
    }

    fun scroll(direction: Int): Boolean {
        val root = rootInActiveWindow ?: return false
        var done=false
        walk(root,0) { n,_ ->
            if(!done && n.isScrollable) {
                val a=if(direction<0) AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD else AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                done=n.performAction(a)
            }
        }
        return done
    }

    fun pressEnter(): Boolean {
        val root=rootInActiveWindow ?: return false
        val focused=root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        val current=focused.text?.toString() ?: ""
        val args=Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,current+"\n") }
        return focused.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT,args)
    }

    fun pressTab(): Boolean {
        val root=rootInActiveWindow ?: return false
        val focused=root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: return false
        val next=focused.focusSearch(android.view.View.FOCUS_FORWARD) ?: return false
        return next.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
    }
}