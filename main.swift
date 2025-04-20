import Foundation

// MARK: - Data Structures

struct TradingData: CustomStringConvertible { // Added CustomStringConvertible for easier debugging
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int

    var description: String {
        return "TradingData(timestamp: \(timestamp), open: \(open), high: \(high), low: \(low), close: \(close), volume: \(volume))"
    }
}

struct TradingAnalytics {
    let bestBuyPrice: Double
    let bestSellPrice: Double
    let trendingDays: [String: Int] // Day Symbol -> Strength Score
    let trendingHours: [Int: Int]   // Hour (0-23) -> Strength Score
    let highestVolumeHours: [Int: Int] // Hour (0-23) -> Total Volume
    let recommendations: [String]
    let priceZones: [String: (count: Int, importance: Double)]? // Price Bucket -> Stats
    let momentum: Double? // Last calculated momentum value
    let prediction: String? // Prediction based on momentum
    let patterns: [(pattern: PricePattern, confidence: Double)]? // Detected patterns
    let volatility: Double? // Average price range (high-low)
    let volatilityAssessment: String? // Assessment based on volatility value
    let intradayPatterns: [Int: (volatility: Double, direction: String, volume: Int)]? // Hour -> Stats
    let enhancedRecommendations: [String]?
}

// MARK: - CSV Parsing

class TradingDataParser {
    private let dateFormatter: DateFormatter

    init() {
        dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Consistent locale
        // !!! CRITICAL: Adjust this format string to EXACTLY match your CSV data !!!
        // Updated format based on user example: "2025-04-14 10:00:00+01:00"
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ssZZZZZ" // <-- UPDATED DATE FORMAT
    }

    func parseCSVFile(at path: String) -> Result<[TradingData], Error> {
        let fileName = URL(fileURLWithPath: path).lastPathComponent // For better error messages
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)

            // --- Use components(separatedBy:) for simpler line splitting ---
            let lines = content.components(separatedBy: .newlines)

            var tradingData: [TradingData] = []

            // --- Updated NSRegularExpression pattern string ---
            // Matches: DateTime (YYYY-MM-DD HH:MM:SS+HH:MM), Open, High, Low, Close, Volume
            // Allows optional spaces around commas, optional +/- signs for numbers
            // Updated Date Part: (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2})
            let pricePattern = try NSRegularExpression(pattern: "^(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}[+-]\\d{2}:\\d{2}),[ ]?([+-]?\\d*\\.?\\d+),[ ]?([+-]?\\d*\\.?\\d+),[ ]?([+-]?\\d*\\.?\\d+),[ ]?([+-]?\\d*\\.?\\d+),[ ]?(\\d+)$") // <-- UPDATED REGEX

            // Process lines, skipping potential headers or empty lines
            for (index, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)

                // --- UPDATED HEADER/EMPTY LINE SKIP LOGIC ---
                // Skip empty lines, the header line (index == 0), or lines without commas
                if trimmedLine.isEmpty || index == 0 || !trimmedLine.contains(",") {
                     continue
                }

                // --- Use NSRange correctly with the string's bounds ---
                let range = NSRange(trimmedLine.startIndex..<trimmedLine.endIndex, in: trimmedLine)

                // --- Call 'firstMatch', not the regex object itself ---
                guard let match = pricePattern.firstMatch(in: trimmedLine, options: [], range: range) else {
                    // This warning might still appear for lines that are not empty, not the header,
                    // contain a comma, but still don't match the data pattern (e.g., malformed data).
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Line did not match expected data pattern: \"\(trimmedLine)\"")
                    continue
                }

                // --- Helper to extract groups using range(at:) ---
                func groupString(_ groupIndex: Int, in text: String, from match: NSTextCheckingResult) -> String? {
                    let nsRange = match.range(at: groupIndex)
                    guard nsRange.location != NSNotFound,
                          let swiftRange = Range(nsRange, in: text) else {
                        return nil
                    }
                    return String(text[swiftRange])
                }

                // --- Extract groups (Group 0 is whole match, 1-6 are captures) ---
                guard match.numberOfRanges == 7, // 1 overall + 6 captures
                      let dateStr = groupString(1, in: trimmedLine, from: match),
                      let openStr = groupString(2, in: trimmedLine, from: match)?.trimmingCharacters(in: .whitespaces),
                      let highStr = groupString(3, in: trimmedLine, from: match)?.trimmingCharacters(in: .whitespaces),
                      let lowStr = groupString(4, in: trimmedLine, from: match)?.trimmingCharacters(in: .whitespaces),
                      let closeStr = groupString(5, in: trimmedLine, from: match)?.trimmingCharacters(in: .whitespaces),
                      let volumeStr = groupString(6, in: trimmedLine, from: match)?.trimmingCharacters(in: .whitespaces) else {
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Could not extract all expected groups from line: \"\(trimmedLine)\"")
                    continue
                }

                // --- Convert extracted strings with error checking ---
                var errorDetails = "" // Keep for potential logging inside guards if needed later

                // Use guard let to create non-optional versions
                guard let date = dateFormatter.date(from: dateStr) else {
                    errorDetails = "   - Date parse error for: '\(dateStr)' using format '\(dateFormatter.dateFormat ?? "nil")'\n" // Assign error detail
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Failed to convert values from line: \"\(trimmedLine)\"\n\(errorDetails)") // Log immediately
                    continue // <-- Exit loop iteration on error
                }
                guard let open = Double(openStr) else {
                    errorDetails = "   - Open parse error for: '\(openStr)'\n"
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Failed to convert values from line: \"\(trimmedLine)\"\n\(errorDetails)")
                    continue // <-- Exit loop iteration on error
                }
                guard let high = Double(highStr) else {
                    errorDetails = "   - High parse error for: '\(highStr)'\n"
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Failed to convert values from line: \"\(trimmedLine)\"\n\(errorDetails)")
                    continue // <-- Exit loop iteration on error
                }
                guard let low = Double(lowStr) else {
                    errorDetails = "   - Low parse error for: '\(lowStr)'\n"
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Failed to convert values from line: \"\(trimmedLine)\"\n\(errorDetails)")
                    continue // <-- Exit loop iteration on error
                }
                guard let close = Double(closeStr) else {
                    errorDetails = "   - Close parse error for: '\(closeStr)'\n"
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Failed to convert values from line: \"\(trimmedLine)\"\n\(errorDetails)")
                    continue // <-- Exit loop iteration on error
                }
                guard let volume = Int(volumeStr) else {
                    errorDetails = "   - Volume parse error for: '\(volumeStr)'\n"
                    print("⚠️ Parser Warning [\(fileName) line \(index + 1)]: Failed to convert values from line: \"\(trimmedLine)\"\n\(errorDetails)")
                    continue // <-- Exit loop iteration on error
                }

                // Variables date, open, high, low, close, volume are guaranteed
                // to be non-optional here because of the guard statements above.
                tradingData.append(TradingData(
                    timestamp: date,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                ))

            } // End line loop

            if tradingData.isEmpty && !lines.filter({ !$0.isEmpty }).isEmpty {
                 print("⚠️ Parser Warning [\(fileName)]: File read but NO trading data successfully parsed. Check CSV format, regex pattern ('\(pricePattern.pattern)'), and date format string ('\(dateFormatter.dateFormat ?? "nil")').")
            }
            return .success(tradingData)

        } catch {
            print("❌ Parser Error [\(fileName)]: Failed to read file: \(error)")
            return .failure(NSError(domain: "CSV Parsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read file \(path): \(error.localizedDescription)"]))
        }
    }
}


// MARK: - Price Pattern Enum

enum PricePattern: String {
    case doubleTop = "Double Top"
    case doubleBottom = "Double Bottom"
    case headAndShoulders = "Head and Shoulders"
    case triangle = "Triangle Pattern"
    case breakout = "Breakout"
    case none = "No significant pattern"
}

// MARK: - Analytics Engine

class TradingAnalyticsEngine {

    // Centralized Calendar instance
    private let calendar = Calendar.current

    func analyzeData(filePaths: [String]) -> Result<TradingAnalytics, Error> {
        guard !filePaths.isEmpty else {
             return .failure(NSError(domain: "Input", code: 1, userInfo: [NSLocalizedDescriptionKey: "No input file paths provided."]))
        }

        let parser = TradingDataParser()
        var allData: [TradingData] = []
        var fileParseErrors = 0

        print("Parsing \(filePaths.count) data files...")

        for path in filePaths {
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            print("   Parsing: \(fileName)")

            // --- Call parseCSVFile directly, no try/catch needed here ---
            let result = parser.parseCSVFile(at: path) // Returns Result<[TradingData], Error>

            // --- Handle the returned Result ---
            switch result {
            case .success(let records):
                 if records.isEmpty && FileManager.default.fileExists(atPath: path) {
                      print("   ⚠️ Parsed \(fileName) but found 0 valid records (Check format/regex/date).")
                 } else if !records.isEmpty {
                      print("   ✅ Parsed \(records.count) records from \(fileName)")
                 }
                 // If file didn't exist, parseCSVFile returns failure handled below
                allData.append(contentsOf: records)
            case .failure(let error):
                // Error details should be printed inside parseCSVFile
                print("   ❌ Failed to process file \(fileName): \(error.localizedDescription)")
                fileParseErrors += 1
                // return .failure(error) // Option: uncomment to stop analysis on first file error
            }
        } // End file path loop

        guard !allData.isEmpty else {
            let errorMsg = fileParseErrors == filePaths.count ? "All \(filePaths.count) files failed to parse." : "No valid trading data successfully parsed from any provided files."
            print("❌ Analysis Error: \(errorMsg) Analysis cannot proceed.")
            return .failure(NSError(domain: "Data", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(errorMsg) Analysis cannot proceed."]))
        }

        print("Total records parsed across all files: \(allData.count)")
        print("Starting analysis...")

        // Sort data by timestamp just in case files were not ordered
        allData.sort { $0.timestamp < $1.timestamp }

        // --- Call analysis functions ---
        let bestBuyPrice = findBestBuyPrice(in: allData)
        let bestSellPrice = findBestSellPrice(in: allData)
        let trendingDays = analyzeTrendingDays(in: allData)
        let trendingHours = analyzeTrendingHours(in: allData)
        let calculatedHighestVolumeHours = findHighestVolumeHours(in: allData) // Renamed variable for clarity
        let recommendations = generateRecommendations(data: allData) // Simple recommendations

        // --- Call enhanced analysis functions ---
        let priceZones = identifyPriceZones(in: allData)
        let momentumAnalysis = analyzePriceMomentum(in: allData)
        let patterns = identifyPricePatterns(in: allData) // Placeholder
        let volatilityAnalysis = analyzeVolatility(in: allData)
        let intradayPatterns = analyzeIntraday(in: allData)
        // --- FIX: Pass calculatedHighestVolumeHours to generateEnhancedRecommendations ---
        let enhancedRecommendations = generateEnhancedRecommendations(
            data: allData,
            momentum: momentumAnalysis.momentum,
            volatility: volatilityAnalysis.volatility,
            highestVolumeHours: calculatedHighestVolumeHours // Pass the dictionary here
        )

        print("Analysis complete.")

        // --- Return combined results ---
        return .success(TradingAnalytics(
            bestBuyPrice: bestBuyPrice,
            bestSellPrice: bestSellPrice,
            trendingDays: trendingDays,
            trendingHours: trendingHours,
            highestVolumeHours: calculatedHighestVolumeHours, // Assign the calculated dictionary
            recommendations: recommendations, // Keep simple ones
            priceZones: priceZones,
            momentum: momentumAnalysis.momentum,
            prediction: momentumAnalysis.prediction,
            patterns: patterns,
            volatility: volatilityAnalysis.volatility,
            volatilityAssessment: volatilityAnalysis.assessment,
            intradayPatterns: intradayPatterns,
            enhancedRecommendations: enhancedRecommendations // Add enhanced ones
        ))
    }

    // MARK: - Basic Analysis Methods

    func findBestBuyPrice(in data: [TradingData]) -> Double {
        guard !data.isEmpty else { return 0 }
        // Use low prices for buying opportunities
        let lowestPrice = data.map { $0.low }.min() ?? 0
        print("   Best Buy Price (Lowest Low): \(lowestPrice)")
        return lowestPrice
    }

    func findBestSellPrice(in data: [TradingData]) -> Double {
        guard !data.isEmpty else { return 0 }
        // Use high prices for selling opportunities
        let highestPrice = data.map { $0.high }.max() ?? 0
        print("   Best Sell Price (Highest High): \(highestPrice)")
        return highestPrice
    }

    func analyzeTrendingDays(in data: [TradingData]) -> [String: Int] {
        guard !data.isEmpty else { return [:] }
        // Use the shared calendar instance
        var dayStrength: [String: Int] = Dictionary(uniqueKeysWithValues: calendar.shortWeekdaySymbols.map { ($0, 0) })

        for dataPoint in data {
            let date = dataPoint.timestamp
            // --- Use component(_:from:) to get weekday ---
            let weekdayComponent = calendar.component(.weekday, from: date) // 1-7
            let daySymbolIndex = weekdayComponent - 1 // 0-6 for array index

            // --- Use shortWeekdaySymbols array ---
            if daySymbolIndex >= 0 && daySymbolIndex < calendar.shortWeekdaySymbols.count {
                let day = calendar.shortWeekdaySymbols[daySymbolIndex]
                // Example strength: absolute difference between open and close
                dayStrength[day]? += Int(abs(dataPoint.close - dataPoint.open))
            }
        }
        print("   Trending Days (Strength Score): \(dayStrength.filter { $1 != 0 })")
        return dayStrength
    }

    func analyzeTrendingHours(in data: [TradingData]) -> [Int: Int] {
        guard !data.isEmpty else { return [:] }
        // Use the shared calendar instance
        var hourStrength: [Int: Int] = Dictionary(uniqueKeysWithValues: (0...23).map { ($0, 0) })

        for dataPoint in data {
            let date = dataPoint.timestamp
            // --- Use component(_:from:) to get hour ---
            let hour = calendar.component(.hour, from: date)
            if hour >= 0 && hour <= 23 {
                // Example strength: absolute difference between open and close
                hourStrength[hour]? += Int(abs(dataPoint.close - dataPoint.open))
            }
        }
        print("   Trending Hours (Strength Score): \(hourStrength.filter { $1 != 0 })")
        return hourStrength
    }

    func findHighestVolumeHours(in data: [TradingData]) -> [Int: Int] {
        guard !data.isEmpty else { return [:] }
        // Use the shared calendar instance
        var volumeByHour: [Int: Int] = Dictionary(uniqueKeysWithValues: (0...23).map { ($0, 0) })

        for dataPoint in data {
            let date = dataPoint.timestamp
            // --- Use component(_:from:) to get hour ---
            let hour = calendar.component(.hour, from: date)
             if hour >= 0 && hour <= 23 {
                 volumeByHour[hour]? += dataPoint.volume
             }
        }
        print("   Highest Volume Hours (Total Volume): \(volumeByHour.filter { $1 != 0 })")
        return volumeByHour
    }

    func generateRecommendations(data: [TradingData]) -> [String] {
        // Basic recommendations based on overall trend (simplified)
        var recommendations: [String] = []
        guard data.count > 1 else { return ["Insufficient data for basic recommendations."] }

        let firstPrice = data.first!.open
        let lastPrice = data.last!.close

        if lastPrice > firstPrice * 1.01 { // Example: >1% increase
            recommendations.append("Overall trend appears upward.")
        } else if lastPrice < firstPrice * 0.99 { // Example: >1% decrease
            recommendations.append("Overall trend appears downward.")
        } else {
            recommendations.append("Overall trend appears relatively flat.")
        }
        return recommendations
    }

    // MARK: - Enhanced Analysis Methods

    func identifyPriceZones(in data: [TradingData], numZones: Int = 10) -> [String: (count: Int, importance: Double)] {
        guard !data.isEmpty else { return [:] }

        let minPrice = data.map { $0.low }.min() ?? 0
        let maxPrice = data.map { $0.high }.max() ?? 0
        guard maxPrice > minPrice else { return [:] } // Avoid division by zero

        let zoneSize = (maxPrice - minPrice) / Double(numZones)
        var priceZones: [String: (count: Int, importance: Double)] = [:]
        let zoneRange = 0.0...Double(numZones - 1) // Define the valid range for indices

        // Initialize zones
        for i in 0..<numZones {
            let lowerBound = minPrice + (Double(i) * zoneSize)
            let upperBound = lowerBound + zoneSize
            let zoneKey = String(format: "%.2f-%.2f", lowerBound, upperBound)
            priceZones[zoneKey] = (count: 0, importance: 0.0)
        }

        // Count how many times the closing price falls into each zone
        for dataPoint in data {
            // Calculate the raw index
            let rawIndex = (dataPoint.close - minPrice) / zoneSize
            // --- FIX: Replace .clamped(to:) with min/max ---
            let clampedIndex = max(zoneRange.lowerBound, min(rawIndex, zoneRange.upperBound))
            let zoneIndex = Int(clampedIndex)

            // Recalculate the key based on the actual clamped index
            let lowerBound = minPrice + (Double(zoneIndex) * zoneSize)
            // Ensure upperBound doesn't exceed maxPrice slightly due to floating point math
            let upperBound = min(lowerBound + zoneSize, maxPrice)
            let zoneKey = String(format: "%.2f-%.2f", lowerBound, upperBound)


            // Increment count if the key exists (it should, due to initialization)
            if priceZones[zoneKey] != nil {
                priceZones[zoneKey]?.count += 1
            } else {
                // This case might happen with edge values if clamping/key calculation isn't perfect
                // Find the closest key or handle appropriately
                 print("⚠️ Price Zone Warning: Could not find exact key '\(zoneKey)' for price \(dataPoint.close). Assigning to nearest zone.")
                 // As a fallback, find the initialized key with the closest lower bound
                 let closestKey = priceZones.keys.min { abs(Double($0.split(separator: "-").first ?? "0") ?? 0 - lowerBound) < abs(Double($1.split(separator: "-").first ?? "0") ?? 0 - lowerBound) }
                 if let key = closestKey {
                     priceZones[key]?.count += 1
                 }
            }
        }

        // Calculate importance (percentage of total data points)
        let totalCount = Double(data.count)
        if totalCount > 0 { // Avoid division by zero if data was empty after all
            for (key, value) in priceZones {
                priceZones[key]?.importance = Double(value.count) / totalCount
            }
        }

        print("   Price Zones (Count & Importance): \(priceZones.filter { $0.value.count > 0 })")
        return priceZones.filter { $0.value.count > 0 } // Return only zones with hits
    }


    func analyzePriceMomentum(in data: [TradingData], windowSize: Int = 10) -> (momentum: Double?, prediction: String?) {
        guard data.count > windowSize else {
            return (nil, "Insufficient data for momentum (need > \(windowSize) points)")
        }

        var momentumValues: [Double] = []
        for i in windowSize..<data.count {
            let currentClose = data[i].close
            let previousClose = data[i - windowSize].close
            // Momentum = Price_today - Price_n_days_ago
            let change = currentClose - previousClose
            momentumValues.append(change)
        }

        guard let lastMomentum = momentumValues.last else {
             return (nil, "Could not calculate momentum") // Should not happen if initial guard passed
        }

        // Simple prediction based on the sign of the last momentum value
        let prediction: String
        if lastMomentum > 0 {
            prediction = "Positive momentum suggests potential upward movement."
        } else if lastMomentum < 0 {
            prediction = "Negative momentum suggests potential downward movement."
        } else {
            prediction = "Momentum is neutral."
        }

        print(String(format: "   Momentum (Last %d-period change): %.2f", windowSize, lastMomentum))
        return (lastMomentum, prediction)
    }

    func identifyPricePatterns(in data: [TradingData]) -> [(pattern: PricePattern, confidence: Double)] {
        // Placeholder: Real pattern detection is complex (requires libraries or significant logic)
        print("   Price Pattern Identification: Not implemented (Placeholder)")
        return [(.none, 0.0)] // Return 'none' as a placeholder
    }

    func analyzeVolatility(in data: [TradingData]) -> (volatility: Double?, assessment: String?) {
        guard !data.isEmpty else { return (nil, "Insufficient data for volatility analysis") }

        // Calculate average daily range (High - Low) as a simple volatility measure
        let priceRanges = data.map { $0.high - $0.low }
        guard !priceRanges.isEmpty else { return (nil, "Could not calculate price ranges.")} // Should not happen if data is not empty
        let averageRange = priceRanges.reduce(0, +) / Double(priceRanges.count)


        let assessment: String
        // Define thresholds based on typical price movement for the asset (adjust as needed)
        let maxClosePrice = data.map{$0.close}.max() ?? 1.0 // Use 1.0 as fallback if max is 0 or data is empty
        let highVolatilityThreshold = maxClosePrice * 0.05 // e.g., 5% of max price
        let moderateVolatilityThreshold = maxClosePrice * 0.02 // e.g., 2% of max price

        if averageRange > highVolatilityThreshold {
            assessment = "High volatility environment."
        } else if averageRange > moderateVolatilityThreshold {
            assessment = "Moderate volatility environment."
        } else {
            assessment = "Low volatility environment."
        }

        print(String(format:"   Volatility (Avg Range): %.2f, Assessment: %@", averageRange, assessment))
        return (averageRange, assessment)
    }

    func analyzeIntraday(in data: [TradingData]) -> [Int: (volatility: Double, direction: String, volume: Int)] {
         guard !data.isEmpty else { return [:] }
         // Use the shared calendar instance
         var intradayStats: [Int: (volatility: Double, direction: String, volume: Int)] = [:]

         // Group data by hour first
         let groupedByHour = Dictionary(grouping: data) {
             // --- Use component(_:from:) to get hour ---
             calendar.component(.hour, from: $0.timestamp)
         }

         for hour in 0...23 {
             guard let hourlyData = groupedByHour[hour], !hourlyData.isEmpty else {
                 // Optionally add placeholder for hours with no data
                 // intradayStats[hour] = (volatility: 0, direction: "N/A", volume: 0)
                 continue // Skip hours with no data
             }

             let totalVolume = hourlyData.reduce(0) { $0 + $1.volume }
             // Average volatility within the hour
             let avgVolatility = hourlyData.reduce(0.0) { $0 + ($1.high - $1.low) } / Double(hourlyData.count)
             // Determine overall direction for the hour (first open vs last close)
             let firstOpen = hourlyData.first?.open ?? 0
             let lastClose = hourlyData.last?.close ?? 0
             let direction = lastClose > firstOpen ? "Up" : (lastClose < firstOpen ? "Down" : "Flat")

             intradayStats[hour] = (volatility: avgVolatility, direction: direction, volume: totalVolume)
         }
         print("   Intraday Stats by Hour (Avg Volatility, Direction, Total Volume): \(intradayStats)")
         return intradayStats
     }

    // --- FIX: Add highestVolumeHours parameter ---
    func generateEnhancedRecommendations(data: [TradingData], momentum: Double?, volatility: Double?, highestVolumeHours: [Int: Int]) -> [String] {
        var recommendations: [String] = []

        // Combine momentum and volatility insights
        if let mom = momentum, let vol = volatility {
             // Use the volatility assessment thresholds defined in analyzeVolatility for consistency
             let maxClosePrice = data.map{$0.close}.max() ?? 1.0
             let moderateVolatilityThreshold = maxClosePrice * 0.02

            if mom > 0 && vol > moderateVolatilityThreshold {
                recommendations.append("Positive momentum in a volatile market suggests potential buy opportunities, manage risk carefully.")
            } else if mom < 0 && vol > moderateVolatilityThreshold {
                recommendations.append("Negative momentum in a volatile market suggests caution or potential short opportunities, manage risk carefully.")
            } else if mom > 0 && vol <= moderateVolatilityThreshold {
                 recommendations.append("Positive momentum in a low volatility market might indicate a steady climb.")
            } else if mom < 0 && vol <= moderateVolatilityThreshold {
                 recommendations.append("Negative momentum in a low volatility market might indicate a steady decline.")
            } else {
                 recommendations.append("Neutral momentum detected.")
            }
        } else {
            recommendations.append("Could not generate momentum/volatility recommendations due to missing data.")
        }

        // --- FIX: Use the passed highestVolumeHours dictionary ---
        // Find the hour with the maximum volume from the provided dictionary
        let topVolumeHour = highestVolumeHours.max { $0.value < $1.value }
        if let hour = topVolumeHour, hour.value > 0 { // Check if there was any volume
             recommendations.append("Highest trading volume typically occurs around hour \(hour.key).")
        } else {
             recommendations.append("Volume distribution data unavailable or zero.")
        }


        if recommendations.isEmpty {
            recommendations.append("No specific enhanced recommendations generated based on current rules.")
        }

        return recommendations
    }
}


// MARK: - Main Application

func runTradingAnalysis() {
    print("Starting trading analysis...")

    // --- Configuration ---
    // Define base paths to search for CSV files
    let possiblePaths = [ // ADJUST THESE PATHS AS NEEDED
        "/Volumes/SSD/Xcode Projects/Analyser/Analyser", // Original path
        FileManager.default.currentDirectoryPath, // Directory where the executable is run
        // Add other potential locations if necessary
        // NSHomeDirectory() + "/Documents/TradingData",
    ]
    // --- UPDATED INPUT FILE NAMES ---
    // Define the pattern for input file names based on user input
    let inputFileNames: [String] = (1...7).map { "\($0)daysBTC.csv" } // <-- UPDATED PATTERN & COUNT

    print("Searching for files in: \(possiblePaths)")
    print("Using filename pattern like: \(inputFileNames.first ?? "N/A")")
    // --- End Configuration ---


    // Helper function to find the first valid path for a file
    func findValidFilePath(for fileName: String, in searchPaths: [String]) -> String? {
        for path in searchPaths {
            // Construct URL first for correct path handling
            let fullPathURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fullPathURL.path) {
                // print("   Found file: \(fullPathURL.path)") // Optional debug logging
                return fullPathURL.path
            }
        }
        // Print warning only once per file if not found in any path
        // print("⚠️ File not found - \(fileName) in any search path.") // Keep this commented unless debugging file finding
        return nil
    }

    let analyticsEngine = TradingAnalyticsEngine()

    // --- Process Files Function ---
    // Processes a single file and returns its analytics result
    func processFile(_ fileName: String, engine: TradingAnalyticsEngine) -> TradingAnalytics? {
        guard let filePath = findValidFilePath(for: fileName, in: possiblePaths) else {
             // Only print warning if file finding is being debugged
             // print("   Skipping analysis for \(fileName) - file not found.")
             return nil // Skip if file not found
        }

        print("\n--- Processing: \(fileName) ---") // Clear separator for each file

        // --- Call analyzeData synchronously, handle the result ---
        // NOTE: analyzeData processes *all* files passed to it.
        // To analyze one file at a time, we pass only the current filePath.
        let result: Result<TradingAnalytics, Error> = engine.analyzeData(filePaths: [filePath])

        switch result {
        case .success(let analytics):
            print("✅ SUCCESS: Analysis complete for \(fileName)")
            // Print results concisely here
            print("   Best Buy: \(String(format: "%.2f", analytics.bestBuyPrice)), Best Sell: \(String(format: "%.2f", analytics.bestSellPrice))")
            if let mom = analytics.momentum { print(String(format: "   Momentum: %.2f (%@)", mom, analytics.prediction ?? "N/A")) }
            if let vol = analytics.volatility { print(String(format: "   Volatility (Avg Range): %.2f (%@)", vol, analytics.volatilityAssessment ?? "N/A")) }
            print("   Simple Recs: \(analytics.recommendations)")
            if let enhanced = analytics.enhancedRecommendations { print("   Enhanced Recs: \(enhanced)")}
            // Add more printing if desired
            return analytics
        case .failure(let error):
            // Error should have been printed within analyzeData or parseCSVFile
            print("❌ FAILURE: Could not complete analysis for \(fileName): \(error.localizedDescription)")
            return nil
        }
    }
    // --- End Process Files Function ---


    // --- Main Processing Loop ---
    var allAnalytics: [String: TradingAnalytics] = [:]
    var filesProcessed = 0
    var filesFailed = 0
    let totalFiles = inputFileNames.count

    print("\n--- Starting Batch Processing (\(totalFiles) files) ---")
    for (index, fileName) in inputFileNames.enumerated() {
         // Provide progress update
         print("   [\(index + 1)/\(totalFiles)] Checking file: \(fileName)...")
        if let analyticsResult = processFile(fileName, engine: analyticsEngine) {
            allAnalytics[fileName] = analyticsResult
            filesProcessed += 1
        } else {
            // Failure reason printed by processFile or findValidFilePath
            filesFailed += 1
        }
        // Optional: Add a small delay if processing many files and hitting performance limits
        // Thread.sleep(forTimeInterval: 0.05)
    }
    print("\n--- Batch Processing Finished ---")
    print("Successfully analyzed: \(filesProcessed) files.")
    print("Failed or skipped: \(filesFailed) files.")

    // Optional: Perform further analysis combining results from `allAnalytics`
    if !allAnalytics.isEmpty {
        print("\nCombined analysis could be performed here.")
        // Example: Find the day with the overall highest volatility across all files
        let overallHighestVolatility = allAnalytics.values.compactMap { $0.volatility }.max()
        if let highestVol = overallHighestVolatility {
             print(String(format: "   Overall highest average daily range found: %.2f", highestVol))
        }
    }

} // End runTradingAnalysis


// MARK: - Entry Point

func startAnalysis() {
    let startTime = Date()
    print("========================================")
    print("      Trading Data Analysis Started     ")
    print("========================================")
    print("Start Time: \(startTime)")

    runTradingAnalysis()

    let endTime = Date()
    let timeInterval = endTime.timeIntervalSince(startTime)
    print("\n========================================")
    print("      Trading Data Analysis Finished    ")
    print("========================================")
    print("End Time: \(endTime)")
    print(String(format: "Total Execution Time: %.2f seconds", timeInterval))
}

// MARK: - Helper Extensions (Optional but useful)

extension Double {
    /// Clamps the Double value to the given closed range.
    /// - Parameter range: The closed range to clamp the value to.
    /// - Returns: The clamped value.
    func clamped(to range: ClosedRange<Double>) -> Double {
        return max(range.lowerBound, min(self, range.upperBound))
    }
}


// --- Main execution ---
startAnalysis()

// Ensure no extra characters or braces after this line

