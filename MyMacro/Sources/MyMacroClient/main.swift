import MyMacro

let a = 17
let b = 25

let (result, code) = #stringify(a + b)

print("The value \(result) was produced by the code \"\(code)\"")


@codableEnum
enum CanadianStatus {
    case visitor
    case study
    case workPermit
    case pr
    case citizen
}
