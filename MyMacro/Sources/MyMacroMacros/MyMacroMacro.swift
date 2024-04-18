import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `stringify` macro, which takes an expression
/// of any type and produces a tuple containing the value of that expression
/// and the source code that produced the value. For example
///
///     #stringify(x + y)
///
///  will expand to
///
///     (x + y, "x + y")
public struct StringifyMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        guard let argument = node.argumentList.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return "(\(argument), \(literal: argument.description))"
    }
}



public struct NullableEnumMacro: MemberMacro {
    public static func expansion(of node: AttributeSyntax, 
                                 providingMembersOf declaration: some DeclGroupSyntax,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard let enumDecl = declaration .as(EnumDeclSyntax.self) else {
            //throw error here
            return []
        }
        
        let members = enumDecl.memberBlock.members
        let caseDecl = members.compactMap({ $0.decl.as(EnumCaseDeclSyntax.self)})
        let elements = caseDecl.flatMap { $0.elements }
        
        let initializerDecl = try InitializerDeclSyntax("init(with rawValue: String)") {
            try SwitchExprSyntax("switch rawValue") {
                for element in elements {
                        """
                        case "\(element.name)":
                            self = .\(element.name)
                        """
                }
                SwitchCaseSyntax("default: self = .unknown")
            }
        }
        
        return [DeclSyntax(try EnumCaseDeclSyntax("case unknown")), DeclSyntax(initializerDecl)]
    }
}

public enum CodableError: Error {
    case failed
}

public struct CodableEnumMacro: ExtensionMacro, MemberMacro {
    public static func expansion(of node: SwiftSyntax.AttributeSyntax,
                                 attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
                                 providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
                                 conformingTo protocols: [SwiftSyntax.TypeSyntax],
                                 in context: some SwiftSyntaxMacros.MacroExpansionContext) throws -> [SwiftSyntax.ExtensionDeclSyntax] {
        
        
        guard let enumDecl = declaration .as(EnumDeclSyntax.self) else {
            //throw error here
            return []
        }
        
        let members = enumDecl.memberBlock.members
        let caseDecl = members.compactMap({ $0.decl.as(EnumCaseDeclSyntax.self)})
        let elements = caseDecl.flatMap { $0.elements }
        
        let decoExtensionSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Decodable") {
            try InitializerDeclSyntax("init(from decoder: Decoder) throws)") {
                "let value = try decoder.singleValueContainer().decode(String.self)"
                
                try SwitchExprSyntax("switch value") {
                    for element in elements {
                                                """
                                                case "\(element.name)":
                                                   self = .\(element.name)
                                                """
                    }
                    SwitchCaseSyntax("default: self = .unknown")
                }
            }
        }
        
        let encoExtensionSyntax = try ExtensionDeclSyntax("extension \(type.trimmed): Encodable") {
            try FunctionDeclSyntax("func encode(to encoder: Encoder) throws") {
                "var container = encoder.singleValueContainer()"
                
                try SwitchExprSyntax("switch self") {
                    for element in elements {
                                                """
                                                case .\(element.name):
                                                   try container.encode("\(element.name)")
                                                """
                    }
                    SwitchCaseSyntax("""
                        default: try container.encode("Unknown")
                    """)
                }
            }
        }
        
        
        return [decoExtensionSyntax, encoExtensionSyntax]
    }
    
    public static func expansion(of node: AttributeSyntax,
                                 providingMembersOf declaration: some DeclGroupSyntax,
                                 in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else { return [] }
        
        guard let inheritanceType = enumDecl.inheritanceClause?.inheritedTypes.first?.type else { return [] }
        
        let cases = enumDecl.memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self)?.elements }
        
        let newElement = try EnumCaseDeclSyntax("case unknown")
        
        let initializer = try InitializerDeclSyntax("init(rawValue: \(String.self))") {
            try SwitchExprSyntax("switch rawValue") {
                for caseList in cases {
                    for `case` in caseList {
                        SwitchCaseSyntax("""
                                  case Self.\(raw: `case`.name).rawValue:
                                    self = .\(raw: `case`.name)
                                  """)
                    }
                }
                SwitchCaseSyntax("""
                    default: self = .unknown
                """)
            }
        }
        
        let rawValue = try VariableDeclSyntax("var rawValue: \(String.self)") {
            try SwitchExprSyntax("switch self") {
                for caseList in cases {
                    for `case` in caseList {
                        if let rawValueExpr = `case`.rawValue?.value {
                            SwitchCaseSyntax("""
                                      case .\(raw: `case`.name):
                                        return \(rawValueExpr)
                                      """)
                        } else {
                            SwitchCaseSyntax("""
                                  case .\(raw: `case`.name):
                                    return \(literal: `case`.name.text)
                                  """)
                        }
                    }
                }
                SwitchCaseSyntax("""
                          case .unknown:
                            return "Unknown"
                          """)
            }
        }
        
        return [DeclSyntax(newElement), DeclSyntax(initializer), DeclSyntax(rawValue)]
    }
}

@main
struct MyMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StringifyMacro.self,
        NullableEnumMacro.self,
        CodableEnumMacro.self
    ]
}
