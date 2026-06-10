use std::net::{Ipv4Addr, Ipv6Addr};

const DNS_CLASS_IN: u16 = 1;
const DNS_HEADER_LEN: usize = 12;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecordType {
    A,
    Aaaa,
}

impl RecordType {
    fn code(self) -> u16 {
        match self {
            Self::A => 1,
            Self::Aaaa => 28,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DnsResponse {
    pub transaction_id: u16,
    pub response_code: u8,
    pub answers: Vec<DnsAnswer>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DnsAnswer {
    pub name: String,
    pub ttl_seconds: u32,
    pub data: DnsRecordData,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DnsRecordData {
    A(Ipv4Addr),
    Aaaa(Ipv6Addr),
    Unsupported { record_type: u16, bytes: Vec<u8> },
}

#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum DnsWireError {
    #[error("domain is empty")]
    EmptyDomain,
    #[error("invalid DNS label: {0}")]
    InvalidLabel(String),
    #[error("DNS packet is truncated")]
    TruncatedPacket,
    #[error("DNS name compression loop detected")]
    CompressionLoop,
    #[error("invalid DNS name")]
    InvalidName,
}

pub fn build_query(
    transaction_id: u16,
    domain: &str,
    record_type: RecordType,
) -> Result<Vec<u8>, DnsWireError> {
    let mut packet = Vec::with_capacity(512);
    packet.extend(transaction_id.to_be_bytes());
    packet.extend(0x0100_u16.to_be_bytes());
    packet.extend(1_u16.to_be_bytes());
    packet.extend(0_u16.to_be_bytes());
    packet.extend(0_u16.to_be_bytes());
    packet.extend(0_u16.to_be_bytes());
    encode_name(domain, &mut packet)?;
    packet.extend(record_type.code().to_be_bytes());
    packet.extend(DNS_CLASS_IN.to_be_bytes());
    Ok(packet)
}

pub fn validate_domain_name(domain: &str) -> Result<(), DnsWireError> {
    let mut packet = Vec::new();
    encode_name(domain, &mut packet)
}

pub fn parse_response(packet: &[u8]) -> Result<DnsResponse, DnsWireError> {
    if packet.len() < DNS_HEADER_LEN {
        return Err(DnsWireError::TruncatedPacket);
    }

    let transaction_id = read_u16(packet, 0)?;
    let flags = read_u16(packet, 2)?;
    let question_count = read_u16(packet, 4)? as usize;
    let answer_count = read_u16(packet, 6)? as usize;
    let response_code = (flags & 0x000f) as u8;

    let mut offset = DNS_HEADER_LEN;
    for _ in 0..question_count {
        let (_, next) = decode_name(packet, offset)?;
        offset = next + 4;
        if offset > packet.len() {
            return Err(DnsWireError::TruncatedPacket);
        }
    }

    let mut answers = Vec::with_capacity(answer_count);
    for _ in 0..answer_count {
        let (name, next) = decode_name(packet, offset)?;
        offset = next;

        let record_type = read_u16(packet, offset)?;
        let record_class = read_u16(packet, offset + 2)?;
        let ttl_seconds = read_u32(packet, offset + 4)?;
        let data_len = read_u16(packet, offset + 8)? as usize;
        offset += 10;

        let data_end = offset
            .checked_add(data_len)
            .ok_or(DnsWireError::TruncatedPacket)?;
        if data_end > packet.len() {
            return Err(DnsWireError::TruncatedPacket);
        }

        let bytes = &packet[offset..data_end];
        offset = data_end;

        if record_class != DNS_CLASS_IN {
            continue;
        }

        let data = match (record_type, data_len) {
            (1, 4) => DnsRecordData::A(Ipv4Addr::new(bytes[0], bytes[1], bytes[2], bytes[3])),
            (28, 16) => DnsRecordData::Aaaa(Ipv6Addr::new(
                u16::from_be_bytes([bytes[0], bytes[1]]),
                u16::from_be_bytes([bytes[2], bytes[3]]),
                u16::from_be_bytes([bytes[4], bytes[5]]),
                u16::from_be_bytes([bytes[6], bytes[7]]),
                u16::from_be_bytes([bytes[8], bytes[9]]),
                u16::from_be_bytes([bytes[10], bytes[11]]),
                u16::from_be_bytes([bytes[12], bytes[13]]),
                u16::from_be_bytes([bytes[14], bytes[15]]),
            )),
            _ => DnsRecordData::Unsupported {
                record_type,
                bytes: bytes.to_vec(),
            },
        };

        answers.push(DnsAnswer {
            name,
            ttl_seconds,
            data,
        });
    }

    Ok(DnsResponse {
        transaction_id,
        response_code,
        answers,
    })
}

fn encode_name(domain: &str, packet: &mut Vec<u8>) -> Result<(), DnsWireError> {
    let trimmed = domain.trim_end_matches('.');
    if trimmed.is_empty() {
        return Err(DnsWireError::EmptyDomain);
    }

    for label in trimmed.split('.') {
        if label.is_empty()
            || label.len() > 63
            || !label
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
            || label.starts_with('-')
            || label.ends_with('-')
        {
            return Err(DnsWireError::InvalidLabel(label.into()));
        }

        packet.push(label.len() as u8);
        packet.extend(label.as_bytes());
    }

    packet.push(0);
    Ok(())
}

fn decode_name(packet: &[u8], offset: usize) -> Result<(String, usize), DnsWireError> {
    let mut labels = Vec::new();
    let mut cursor = offset;
    let mut consumed_end = None;
    let mut jumps = 0;

    loop {
        if cursor >= packet.len() {
            return Err(DnsWireError::TruncatedPacket);
        }

        let length = packet[cursor];
        if length & 0xc0 == 0xc0 {
            if cursor + 1 >= packet.len() {
                return Err(DnsWireError::TruncatedPacket);
            }
            let pointer = (((length & 0x3f) as usize) << 8) | packet[cursor + 1] as usize;
            consumed_end.get_or_insert(cursor + 2);
            cursor = pointer;
            jumps += 1;
            if jumps > 16 {
                return Err(DnsWireError::CompressionLoop);
            }
            continue;
        }

        if length & 0xc0 != 0 {
            return Err(DnsWireError::InvalidName);
        }

        cursor += 1;
        if length == 0 {
            let next = consumed_end.unwrap_or(cursor);
            return Ok((labels.join("."), next));
        }

        let label_end = cursor + length as usize;
        if label_end > packet.len() {
            return Err(DnsWireError::TruncatedPacket);
        }
        let label = std::str::from_utf8(&packet[cursor..label_end])
            .map_err(|_| DnsWireError::InvalidName)?;
        labels.push(label.to_string());
        cursor = label_end;
    }
}

fn read_u16(packet: &[u8], offset: usize) -> Result<u16, DnsWireError> {
    if offset + 2 > packet.len() {
        return Err(DnsWireError::TruncatedPacket);
    }
    Ok(u16::from_be_bytes([packet[offset], packet[offset + 1]]))
}

fn read_u32(packet: &[u8], offset: usize) -> Result<u32, DnsWireError> {
    if offset + 4 > packet.len() {
        return Err(DnsWireError::TruncatedPacket);
    }
    Ok(u32::from_be_bytes([
        packet[offset],
        packet[offset + 1],
        packet[offset + 2],
        packet[offset + 3],
    ]))
}

