import AemiProtobufCore

extension WireValidator {
    /// One message waiting to be checked.
    private struct Job {
        let range: Range<Int>
        /// The message's fully qualified name, the scope its fields' type names resolve in.
        let scope: String
        let descriptor: MessageDescriptor
        let path: String
        let depth: Int
    }

    /// Checks `bytes` as the message `messageName` of `set`, and every message nested in it, with an explicit work queue (no
    /// recursion, so nesting cannot exhaust the stack). Type names resolve by protobuf's scoping rule (``SchemaIndex``).
    ///
    /// Findings come shallowest first, each with the path of fields to its message. A message-typed field whose type resolves to
    /// nothing, and nesting deeper than `limits.maxDepth`, are findings too. At most `maxFindings` are returned, then a limit marker.
    /// - Parameters:
    ///   - bytes: the serialized message.
    ///   - messageName: fully qualified, without a leading dot: `pkg.Outer.Inner`.
    ///   - set: the descriptors the message and its nested types are looked up in.
    /// - Returns: the findings, shallowest message first; empty when the bytes are valid.
    /// - Complexity: O(bytes + descriptors) plus the index of the set.
    public func validate(bytes: [UInt8], against messageName: String, in set: FileDescriptorSet) -> [WireFinding] {
        let index = SchemaIndex(set)
        guard let root = index.message(named: messageName) else {
            return [WireFinding(path: "", error: .unknownMessage(messageName))]
        }
        var findings: [WireFinding] = []
        var queue = [Job(range: 0 ..< bytes.count, scope: messageName, descriptor: root, path: "", depth: 0)]
        var head = 0
        while head < queue.count {
            let job = queue[head]
            head += 1
            let check = checkMessage(
                bytes, job.range, job.descriptor, depth: job.depth, budget: maxFindings - findings.count,
                collectNested: true)
            findings += check.errors.map { WireFinding(path: job.path, error: $0) }
            if check.stopped || findings.count >= maxFindings {
                findings.append(WireFinding(path: job.path, error: .findingLimitReached))
                return findings
            }
            for nested in check.nested {
                let path = Self.path(job.path, nested.field, nested.index)
                guard job.depth < limits.maxDepth else {
                    findings.append(
                        WireFinding(
                            path: path,
                            error: .wireCorrupted(.depthExceeded(limit: limits.maxDepth, at: nested.range.lowerBound))))
                    continue
                }
                guard let name = index.resolve(nested.field.typeName, in: job.scope),
                    let descriptor = index.message(named: name)
                else {
                    findings.append(
                        WireFinding(
                            path: path,
                            error: .unresolvedType(field: nested.field.number, typeName: nested.field.typeName)))
                    continue
                }
                queue.append(
                    Job(range: nested.range, scope: name, descriptor: descriptor, path: path, depth: job.depth + 1))
            }
        }
        return findings
    }

    private static func path(_ parent: String, _ field: FieldDescriptor, _ index: Int) -> String {
        let name = field.label == .repeated ? "\(field.name)[\(index)]" : field.name
        return parent.isEmpty ? name : parent + "." + name
    }
}
