//
//  ToolPreset.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 14.10.2026.
//


//
//  ToolPreset.swift
//  Stratum CNC
//
//  A named set of cutting values for a tool, normally one per material.
//  Modelled after the presets in a Fusion 360 tool library.
//
//  Units: lengths in mm, feeds in mm/min, spindle speeds in RPM,
//  surface speed in m/min, angles in degrees.
//  Every value is optional because not every source provides every value.
//

import Foundation

struct ToolPreset: Identifiable, Codable, Hashable {
    var id: UUID

    /// Usually the material this preset is for, e.g. "Aluminum".
    var name: String
    var notes: String?

    // Spindle
    var spindleRPM: Int?
    var rampSpindleRPM: Int?
    /// Cutting speed at the tool edge, m/min.
    var surfaceSpeed: Double?

    // Chip load
    /// Feed per tooth (chip load), mm.
    var feedPerTooth: Double?
    /// Feed per revolution, mm. Fusion pairs it with the plunge feed.
    var feedPerRevolution: Double?

    // Feed rates, mm/min
    var feedRate: Double?
    var plungeFeedRate: Double?
    var rampFeedRate: Double?
    var leadInFeedRate: Double?
    var leadOutFeedRate: Double?
    var transitionFeedRate: Double?
    var retractFeedRate: Double?

    // Engagement
    /// Depth per pass in mm (from the original Makera tables).
    var depthOfCut: Double?
    /// Depth per pass in mm (from Fusion's `stepdown`).
    var stepDown: Double?
    var useStepDown: Bool?
    /// Sideways distance between passes, mm.
    var stepOver: Double?
    var useStepOver: Bool?
    /// Entry angle when ramping down, degrees.
    var rampAngle: Double?

    /// Coolant mode as named by Fusion: "flood", "mist", "disabled", …
    var coolant: String?

    init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        spindleRPM: Int? = nil,
        rampSpindleRPM: Int? = nil,
        surfaceSpeed: Double? = nil,
        feedPerTooth: Double? = nil,
        feedPerRevolution: Double? = nil,
        feedRate: Double? = nil,
        plungeFeedRate: Double? = nil,
        rampFeedRate: Double? = nil,
        leadInFeedRate: Double? = nil,
        leadOutFeedRate: Double? = nil,
        transitionFeedRate: Double? = nil,
        retractFeedRate: Double? = nil,
        depthOfCut: Double? = nil,
        stepDown: Double? = nil,
        useStepDown: Bool? = nil,
        stepOver: Double? = nil,
        useStepOver: Bool? = nil,
        rampAngle: Double? = nil,
        coolant: String? = nil
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.spindleRPM = spindleRPM
        self.rampSpindleRPM = rampSpindleRPM
        self.surfaceSpeed = surfaceSpeed
        self.feedPerTooth = feedPerTooth
        self.feedPerRevolution = feedPerRevolution
        self.feedRate = feedRate
        self.plungeFeedRate = plungeFeedRate
        self.rampFeedRate = rampFeedRate
        self.leadInFeedRate = leadInFeedRate
        self.leadOutFeedRate = leadOutFeedRate
        self.transitionFeedRate = transitionFeedRate
        self.retractFeedRate = retractFeedRate
        self.depthOfCut = depthOfCut
        self.stepDown = stepDown
        self.useStepDown = useStepDown
        self.stepOver = stepOver
        self.useStepOver = useStepOver
        self.rampAngle = rampAngle
        self.coolant = coolant
    }

    /// Converts an entry of the old `[material: parameters]` dictionary.
    init(legacyMaterialKey key: String, parameters: ToolCuttingParameters) {
        self.init(
            name: ToolMaterial(rawValue: key)?.displayName ?? key,
            spindleRPM: parameters.spindleRPM,
            feedRate: parameters.feedRate,
            plungeFeedRate: parameters.plungeFeedRate,
            depthOfCut: parameters.depthOfCut
        )
    }
}