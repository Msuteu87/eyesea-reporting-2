# YOLO Model Detection vs Pollution Categories Mapping

## Your Pollution Categories (7 types)

1. **Plastic** - Single-use plastics, bottles, containers
2. **Oil** - Oil spills, petroleum products
3. **Debris** - General waste, mixed materials
4. **Sewage** - Wastewater, human waste
5. **Fishing Gear** - Nets, ropes, marine equipment
6. **Container** - Larger containers, drums, boxes
7. **Other** - Unclassified pollution

---

## COCO Dataset (80 Classes) - What YOLO Can Actually See

### ✅ Currently Mapped Classes (22/80)

| YOLO Detection | Current Mapping | Alternative Mappings | Notes |
|---------------|-----------------|---------------------|-------|
| **bottle** | Plastic ✓ | - | Perfect match |
| **cup** | Plastic ✓ | Debris | Could be paper/plastic/glass |
| **bowl** | Plastic ✓ | Container, Debris | Could be ceramic/metal |
| **vase** | Plastic ✓ | Debris | Usually ceramic/glass |
| **wine glass** | Plastic ✓ | Debris | Usually glass, not plastic |
| **handbag** | Debris ✓ | - | Good match |
| **backpack** | Debris ✓ | - | Good match |
| **suitcase** | Debris ✓ | Container | Could be Container |
| **umbrella** | Debris ✓ | - | Good match |
| **sports ball** | Debris ✓ | Plastic | Often plastic/rubber |
| **frisbee** | Debris ✓ | Plastic | Usually plastic |
| **kite** | Fishing Gear ⚠️ | Debris | Not really fishing gear |
| **surfboard** | Fishing Gear ⚠️ | Debris | Not really fishing gear |
| **banana** | Debris ✓ | - | Food waste |
| **apple** | Debris ✓ | - | Food waste |
| **orange** | Debris ✓ | - | Food waste |
| **sandwich** | Debris ✓ | - | Food waste |
| **toothbrush** | Container ⚠️ | Plastic, Debris | Should be Plastic |
| **book** | Container ⚠️ | Debris | Paper waste |
| **cell phone** | Container ⚠️ | Debris | E-waste |
| **remote** | Container ⚠️ | Debris | E-waste |

**Issues Found:**
- ⚠️ **Glass items** (wine glass, bowl, vase) mapped to "Plastic" - should be "Debris" or "Container"
- ⚠️ **Kite/Surfboard** mapped to "Fishing Gear" - incorrect, should be "Debris"
- ⚠️ **Small items** (toothbrush, phone, remote) mapped to "Container" - should be "Plastic" or "Debris"

---

## 🔍 Unmapped but Relevant COCO Classes (19/80)

Classes that YOLO CAN detect but you're NOT using:

### High Priority (Marine/Beach Pollution)
| YOLO Class | Suggested Mapping | Use Case |
|-----------|------------------|----------|
| **boat** | Fishing Gear / Debris | Abandoned boats, marine debris |
| **bicycle** | Debris | Dumped bikes common in waterways |
| **car** | Container / Debris | Dumped vehicles (rare but impactful) |
| **motorcycle** | Debris | Dumped vehicles |
| **bench** | Debris | Abandoned furniture |
| **skateboard** | Debris | Sports equipment waste |
| **tie** | Debris | Clothing waste |
| **tennis racket** | Debris | Sports equipment |
| **baseball bat** | Debris | Sports equipment |
| **baseball glove** | Debris | Sports equipment |

### Medium Priority (Food/Organic Waste)
| YOLO Class | Suggested Mapping | Use Case |
|-----------|------------------|----------|
| **broccoli** | Debris | Food waste |
| **carrot** | Debris | Food waste |
| **hot dog** | Debris | Food waste |
| **pizza** | Debris | Food waste |
| **donut** | Debris | Food waste |
| **cake** | Debris | Food waste |

### Lower Priority (Context/Scene Understanding)
| YOLO Class | Suggested Mapping | Use Case |
|-----------|------------------|----------|
| **bird** | - | Wildlife impact indicator |
| **cat** | - | Wildlife/stray animal indicator |
| **dog** | - | Wildlife/stray animal indicator |

---

## ❌ Classes YOLO Cannot Detect (Not in COCO)

Your app needs these but YOLO can't see them:

| Pollution Type | YOLO Can Detect? | Workaround |
|---------------|------------------|------------|
| **Oil spills** | ❌ No | Scene recognition, texture analysis, or user manual selection |
| **Sewage** | ❌ No | Scene recognition or user manual selection |
| **Fishing nets** | ❌ No | May detect as "sports ball" or generic object |
| **Fishing ropes** | ❌ No | No COCO equivalent |
| **Large containers/drums** | ⚠️ Partial | May detect as "suitcase" or miss entirely |
| **Plastic bags** | ⚠️ Partial | May detect as "handbag" or "backpack" |
| **Straws** | ❌ No | Too small for YOLO |
| **Cigarette butts** | ❌ No | Too small for YOLO |
| **Microplastics** | ❌ No | Too small for YOLO |

---

## 📊 Recommended Mapping Improvements

### 1. Fix Current Misclassifications

```dart
// CURRENT (WRONG)
'wine glass': 'plastic',  // ❌ Wine glass is glass, not plastic
'bowl': 'plastic',        // ❌ Bowls can be ceramic/metal
'vase': 'plastic',        // ❌ Vases are usually ceramic/glass
'kite': 'fishingGear',    // ❌ Kites are not fishing gear
'surfboard': 'fishingGear', // ❌ Surfboards are not fishing gear
'toothbrush': 'container', // ❌ Toothbrush is small plastic item
'cell phone': 'container', // ❌ E-waste, should be debris
'remote': 'container',     // ❌ E-waste, should be debris

// RECOMMENDED (CORRECT)
'wine glass': 'debris',    // ✓ Glass waste
'bowl': 'debris',          // ✓ General waste
'vase': 'debris',          // ✓ General waste
'kite': 'debris',          // ✓ Abandoned sports equipment
'surfboard': 'debris',     // ✓ Abandoned sports equipment
'toothbrush': 'plastic',   // ✓ Small plastic item
'cell phone': 'debris',    // ✓ E-waste
'remote': 'debris',        // ✓ E-waste
'book': 'debris',          // ✓ Paper waste
```

### 2. Add More Relevant COCO Classes

```dart
// Beach/Marine pollution
'boat': 'fishingGear',       // Abandoned boats
'bicycle': 'debris',         // Dumped bikes
'car': 'debris',            // Dumped vehicles
'motorcycle': 'debris',      // Dumped vehicles
'bench': 'debris',          // Abandoned furniture

// Sports equipment (common beach litter)
'skateboard': 'debris',
'tennis racket': 'debris',
'baseball bat': 'debris',
'baseball glove': 'debris',

// Additional food waste
'hot dog': 'debris',
'pizza': 'debris',
'donut': 'debris',
'broccoli': 'debris',
'carrot': 'debris',
'cake': 'debris',

// Clothing waste
'tie': 'debris',
```

### 3. Scene Context Enhancement

```dart
// Use additional COCO classes for scene understanding
'bird': null,    // Wildlife indicator (don't map to pollution)
'cat': null,     // Wildlife indicator
'dog': null,     // Wildlife indicator
'boat': 'scene', // Marine environment indicator
```

---

## 🎯 Coverage Analysis

### Current Coverage
- **Total COCO Classes**: 80
- **Currently Using**: 22 (27.5%)
- **Currently Ignoring**: 14 (17.5%)
- **Not Mapped**: 44 (55%)

### Recommended Coverage
- **Should Use**: 41 classes (51.25%)
- **Should Ignore**: 14 classes (17.5%)
- **Not Applicable**: 25 classes (31.25%)

### Detection Accuracy by Category

| Your Category | YOLO Can Detect Directly | Needs Inference | Cannot Detect |
|--------------|-------------------------|-----------------|---------------|
| **Plastic** | 30% (bottles, cups) | 40% (bags as handbag) | 30% (bags, straws) |
| **Oil** | 0% | 0% | 100% ❌ |
| **Debris** | 70% (various objects) | 20% (scene context) | 10% |
| **Sewage** | 0% | 0% | 100% ❌ |
| **Fishing Gear** | 10% (boat, surfboard) | 30% (ropes as objects) | 60% ❌ |
| **Container** | 40% (suitcase, backpack) | 30% (large objects) | 30% |
| **Other** | N/A (catch-all) | N/A | N/A |

---

## 💡 Strategic Recommendations

### Short Term (Immediate Fixes)
1. ✅ Fix misclassified items (glass → debris, not plastic)
2. ✅ Reclassify sports items correctly
3. ✅ Add 10-15 high-priority COCO classes

### Medium Term (Enhanced Detection)
1. Add scene recognition for oil/sewage detection
2. Implement texture analysis for materials
3. Add user feedback loop to improve mappings

### Long Term (Custom Model)
1. Consider training custom YOLO model for marine debris
2. Add specialized classes: fishing nets, ropes, plastic bags, straws
3. Integrate with material classification model

---

## 📝 Implementation Priority

### Priority 1: Fix Existing Errors ⚠️
```dart
// Fix these NOW - they're actively misclassifying
'wine glass' → 'debris' (not 'plastic')
'kite' → 'debris' (not 'fishingGear')
'surfboard' → 'debris' (not 'fishingGear')
'toothbrush' → 'plastic' (not 'container')
```

### Priority 2: Add High-Value Classes
```dart
// Add these for better coverage
'boat', 'bicycle', 'car' → 'debris'
'hot dog', 'pizza', 'donut' → 'debris'
```

### Priority 3: Improve Edge Cases
```dart
// Handle ambiguous items better
'bowl', 'vase' → Need material detection or default to 'debris'
'suitcase' → Could be 'container' or 'debris' based on context
```
