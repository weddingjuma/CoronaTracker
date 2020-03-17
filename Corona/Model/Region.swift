//
//  Region.swift
//  Corona
//
//  Created by Mohammad on 3/4/20.
//  Copyright © 2020 Samabox. All rights reserved.
//

import Foundation

public class Region: Codable {
	public let level: Level
	public let name: String
	public let parentName: String? /// Country name
	public let location: Coordinate

	public var report: Report?
	public var timeSeries: TimeSeries?
	public lazy var dailyChange: Change? = { generateDailyChange() }()

	public var subRegions: [Region] = [] {
		didSet {
			report = Report.join(subReports: subRegions.compactMap { $0.report })
			timeSeries = TimeSeries.join(subSerieses: subRegions.compactMap { $0.timeSeries })
		}
	}

	init(level: Level, name: String, parentName: String?, location: Coordinate) {
		self.level = level
		self.name = name
		self.parentName = parentName
		self.location = location
	}

	private func generateDailyChange() -> Change? {
		if !subRegions.isEmpty {
			return Change.sum(subChanges: subRegions.compactMap { $0.dailyChange })
		}

		guard let todayReport = report,
			let timeSeries = timeSeries else { return nil }

		var yesterdayStat: Statistic
		var dates = timeSeries.series.keys.sorted()
		guard let lastDate = dates.popLast(),
			lastDate.ageDays < 2,
			let lastStat = timeSeries.series[lastDate] else { return nil }

		yesterdayStat = lastStat

		if todayReport.stat.confirmedCount == lastStat.confirmedCount {
			guard let nextToLastDate = dates.popLast(),
				let nextToLastStat = timeSeries.series[nextToLastDate] else { return nil }

			yesterdayStat = nextToLastStat
		}

		let confirmedGrowth = (Double(todayReport.stat.confirmedCount) / Double(yesterdayStat.confirmedCount) - 1) * 100
		let recoveredGrowth = (Double(todayReport.stat.recoveredCount) / Double(yesterdayStat.recoveredCount) - 1) * 100
		let deathsGrowth = (Double(todayReport.stat.deathCount) / Double(yesterdayStat.deathCount) - 1) * 100

		return Change(newConfirmed: todayReport.stat.confirmedCount - yesterdayStat.confirmedCount,
					  newRecovered: todayReport.stat.recoveredCount - yesterdayStat.recoveredCount,
					  newDeaths: todayReport.stat.deathCount - yesterdayStat.deathCount,
					  confirmedGrowthPercent: confirmedGrowth,
					  recoveredGrowthPercent: recoveredGrowth,
					  deathsGrowthPercent: deathsGrowth)
	}

	public enum Level: Int, RawRepresentable, Codable {
		case world = 1
		case country = 2
		case province = 3 /// Could be a province, a state, or a city

		var parent: Level { Level(rawValue: max(1, rawValue - 1)) ?? self }
	}
}

extension Region {
	public var isCountry: Bool { level == .country }
	public var isProvince: Bool { level == .province }
	public var longName: String { isProvince ? "\(name), \(parentName ?? "-")" : name }

	public func find(region: Region) -> Region? {
		if region == self {
			return self
		}

		return subRegions.first { $0 == region }
	}
}

extension Region {
	public static var world: Region { Region(level: .world, name: "Worldwide", parentName: nil, location: .zero) }

	public static func join(subRegions: [Region]) -> Region? {
		guard let firstRegion = subRegions.first else { return nil }

		return Region(level: firstRegion.level.parent,
					  name: subRegions.first!.parentName ?? "N/A",
					  parentName: nil,
					  location: Coordinate.center(of: subRegions.map { $0.location }))
	}
}

extension Region: Equatable {
	public static func == (lhs: Region, rhs: Region) -> Bool {
		(lhs.level == rhs.level && lhs.parentName == rhs.parentName && lhs.name == rhs.name) ||
			lhs.location == rhs.location
	}
}

extension Region: Comparable {
	public static func < (lhs: Region, rhs: Region) -> Bool {
		lhs.report?.stat.confirmedCount ?? 0 < rhs.report?.stat.confirmedCount ?? 0
	}
}